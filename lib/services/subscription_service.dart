import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import 'logger_service.dart';
import 'partner_grant_service.dart';

/// Service for managing subscriptions via RevenueCat
///
/// Usage:
/// - Call `SubscriptionService.initialize()` in main.dart after Firebase init
/// - Check `SubscriptionService.isPremium` to gate features (all paid tiers)
/// - Check `SubscriptionService.isElite` for Elite/Club-only features
/// - Check `SubscriptionService.isClub` for Club-only features
/// - Use `SubscriptionService.showPaywall()` to display subscription options
class SubscriptionService {
  // API keys loaded from .env via EnvConfig
  static String get _iosApiKey => EnvConfig.revenueCatIosApiKey;
  static String get _androidApiKey => EnvConfig.revenueCatAndroidApiKey;

  // Entitlement identifiers - must match RevenueCat dashboard
  static const String premiumEntitlement = 'pro';
  static const String eliteEntitlement = 'elite';
  static const String clubEntitlement = 'club';

  // Cached subscription state
  static bool _isPremium = false;
  static bool _isElite = false;
  static bool _isClub = false;
  static CustomerInfo? _customerInfo;
  static Offerings? _offerings;
  static bool _isInitialized = false;

  // Tier explicitly set by a successful purchase this session.
  // Takes precedence over entitlement-derived tier to handle sandbox lag
  // where a just-cancelled higher tier may still appear active.
  static String? _purchasedTierOverride;

  // Debug tier override for testing (persisted to SharedPreferences)
  // Replaces old boolean _debugPremiumOverride
  static String? _debugTierOverride; // 'pro' | 'elite' | 'club' | null
  static const _debugTierOverrideKey = 'debug_tier_override';
  static const _debugOverrideKeyLegacy = 'debug_premium_override';

  // Stream controller for subscription status changes
  static final _premiumStatusController = StreamController<bool>.broadcast();

  /// Stream of premium status changes
  static Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  // ---------------------------------------------------------------------------
  // Tier getters
  // ---------------------------------------------------------------------------

  /// The user's actual tier from RevenueCat entitlements (no debug override).
  /// If a purchase was just completed, that tier takes precedence until
  /// entitlements from RevenueCat catch up (handles sandbox cancellation lag).
  static String get currentTier {
    if (_purchasedTierOverride != null) return _purchasedTierOverride!;
    return _isClub ? 'club' : _isElite ? 'elite' : _isPremium ? 'pro' : 'free';
  }

  /// Effective tier — applies debug override first, then partner grant.
  /// Partner grant only wins if it provides a HIGHER tier than RevenueCat.
  static String get _effectiveTier {
    if (_debugTierOverride != null) return _debugTierOverride!;
    final rcTier = currentTier;
    final partnerTier = PartnerGrantService.partnerTier;
    if (partnerTier == null) return rcTier;
    const tierRank = {'free': 0, 'pro': 1, 'elite': 2, 'club': 3};
    return (tierRank[partnerTier] ?? 0) > (tierRank[rcTier] ?? 0)
        ? partnerTier
        : rcTier;
  }

  /// True for any paid tier (Pro, Elite, Club). Backwards-compatible with all
  /// existing callsites that check `SubscriptionService.isPremium`.
  static bool get isPremium => _effectiveTier != 'free';

  /// True for all paid tiers — alias of isPremium, kept for semantic clarity.
  static bool get isPro => isPremium;

  /// True for Elite and Club tiers.
  static bool get isElite =>
      _effectiveTier == 'elite' || _effectiveTier == 'club';

  /// True only for Club tier.
  static bool get isClub => _effectiveTier == 'club';

  /// Public read-only view of the effective tier ('free'|'pro'|'elite'|'club').
  /// Applies the debug override and partner grant, unlike [currentTier] which is
  /// raw RevenueCat. Use this for UI that should reflect simulated/granted tiers.
  static String get effectiveTier => _effectiveTier;

  // ---------------------------------------------------------------------------
  // Debug override (tier-based)
  // ---------------------------------------------------------------------------

  /// Set a debug tier override for testing. Pass null to clear.
  /// Accepts: 'pro', 'elite', 'club', or null.
  static Future<void> setDebugTierOverride(String? tier) async {
    if (kReleaseMode) return;
    _debugTierOverride = tier;
    _premiumStatusController.add(isPremium);
    final prefs = await SharedPreferences.getInstance();
    if (tier == null) {
      await prefs.remove(_debugTierOverrideKey);
    } else {
      await prefs.setString(_debugTierOverrideKey, tier);
    }
  }

  /// Backwards-compatible wrapper around setDebugTierOverride.
  static Future<void> setDebugPremiumOverride(bool? value) async {
    await setDebugTierOverride(value == true ? 'pro' : null);
  }

  /// Current debug override state (null = no override).
  static String? get debugTierOverride => _debugTierOverride;

  /// Legacy getter — returns true if override is any paid tier.
  static bool? get debugPremiumOverride =>
      _debugTierOverride == null ? null : _debugTierOverride != 'free';

  /// Load persisted debug override (call during init — debug builds only)
  static Future<void> _loadDebugOverride() async {
    if (kReleaseMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_debugTierOverrideKey)) {
      _debugTierOverride = prefs.getString(_debugTierOverrideKey);
    } else if (prefs.containsKey(_debugOverrideKeyLegacy)) {
      // Migrate legacy boolean key → 'pro' string
      final legacyBool = prefs.getBool(_debugOverrideKeyLegacy);
      if (legacyBool == true) {
        _debugTierOverride = 'pro';
        await prefs.setString(_debugTierOverrideKey, 'pro');
      }
      await prefs.remove(_debugOverrideKeyLegacy);
    }
  }

  // ---------------------------------------------------------------------------
  // Offering getters
  // ---------------------------------------------------------------------------

  /// The single default offering that contains all 6 subscription packages.
  static Offering? get defaultOffering => _offerings?.current;

  // Legacy named-offering getters (kept for backwards compat; prefer defaultOffering)
  static Offering? get proOffering =>
      _offerings?.all['pro'] ?? _offerings?.current;
  static Offering? get eliteOffering => _offerings?.all['elite'];
  static Offering? get clubOffering => _offerings?.all['club'];

  // Legacy getter
  static Offering? get currentOffering => defaultOffering ?? proOffering;

  /// Get all available packages from the default offering.
  static List<Package> get availablePackages =>
      defaultOffering?.availablePackages ?? [];

  /// Look up a package by its identifier in the default offering.
  /// Custom package identifiers (elite_monthly, club_annual, etc.) are only
  /// accessible this way — NOT via the .monthly/.annual convenience getters.
  /// Returns null if the package doesn't exist on the current platform.
  static Package? packageById(String identifier) {
    final packages = defaultOffering?.availablePackages ?? [];
    // Try exact RC package identifier match first
    for (final p in packages) {
      if (p.identifier == identifier) return p;
    }
    // Fallback: match by store product identifier.
    // Store IDs use colons (e.g. 'pro:monthly') while lookup keys use
    // underscores (e.g. 'pro_monthly'), so normalize to compare.
    final normalized = identifier.replaceAll('_', ':');
    for (final p in packages) {
      if (p.storeProduct.identifier == normalized) return p;
    }
    return null;
  }

  // Package identifier constants — must match RevenueCat dashboard
  static const String pkgProMonthly   = r'$rc_monthly';
  static const String pkgProAnnual    = r'$rc_annual';
  static const String pkgEliteMonthly = 'elite_monthly';
  static const String pkgEliteAnnual  = 'elite_annual';
  static const String pkgClubMonthly  = 'club_monthly';
  static const String pkgClubAnnual   = 'club_annual';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Whether the service has been initialized
  static bool get isInitialized => _isInitialized;

  /// Current customer info from RevenueCat
  static CustomerInfo? get customerInfo => _customerInfo;

  /// Available subscription offerings
  static Offerings? get offerings => _offerings;

  /// Initialize RevenueCat SDK
  /// Call this in main.dart after Firebase initialization
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Load any persisted debug override first
    await _loadDebugOverride();

    try {
      // Configure RevenueCat
      final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;

      // Skip initialization if API keys not set
      if (apiKey.isEmpty || apiKey.contains('YOUR_')) {
        await LoggerService.warning('⚠️ RevenueCat API key not configured - running in demo mode');
        _isInitialized = true;
        return;
      }

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      // Listen for customer info updates (subscription changes)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      // Get initial customer info
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(_customerInfo!);

      // Fetch offerings
      await fetchOfferings();

      _isInitialized = true;
      await LoggerService.info('✅ RevenueCat initialized - Tier: $currentTier');
    } catch (e) {
      await LoggerService.error('❌ RevenueCat initialization failed: $e');
      // Continue without subscriptions - features will be unlocked in demo mode
      _isInitialized = true;
    }
  }

  /// Update premium status from customer info
  static void _updatePremiumStatus(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;
    final prevTier = currentTier;
    _isPremium = customerInfo.entitlements.all[premiumEntitlement]?.isActive ?? false;
    _isElite = customerInfo.entitlements.all[eliteEntitlement]?.isActive ?? false;
    _isClub = customerInfo.entitlements.all[clubEntitlement]?.isActive ?? false;

    // Clear the purchased-tier override once entitlements match or exceed it.
    // e.g. after buying Pro: override='pro', entitlements show pro=active → clear.
    if (_purchasedTierOverride != null) {
      final entitlementTier = _isClub ? 'club' : _isElite ? 'elite' : _isPremium ? 'pro' : 'free';
      // Clear when entitlements have caught up to the purchased tier or higher
      const tierRank = {'free': 0, 'pro': 1, 'elite': 2, 'club': 3};
      final overrideRank = tierRank[_purchasedTierOverride] ?? 0;
      final entitlementRank = tierRank[entitlementTier] ?? 0;
      if (entitlementRank >= overrideRank) {
        _purchasedTierOverride = null;
      }
    }

    // Notify listeners on any tier change (not just free/paid)
    if (currentTier != prevTier) {
      _premiumStatusController.add(_isPremium);
      unawaited(LoggerService.logEvent('tier_change', parameters: {
        'from_tier': prevTier,
        'to_tier': currentTier,
      }));
      unawaited(LoggerService.setUserProperties(tier: currentTier));
    }
  }

  /// Called when app returns to foreground. Forces a network fetch so
  /// cancellations made in iOS/Android Settings are reflected immediately.
  /// Uses RevenueCat's invalidateCustomerInfoCache() to bypass local cache.
  static Future<void> refreshOnResume() async {
    if (!_isInitialized) return;
    try {
      await Purchases.invalidateCustomerInfoCache();
      // Clear purchase override so fresh entitlements are authoritative
      _purchasedTierOverride = null;
      final info = await Purchases.getCustomerInfo();
      _updatePremiumStatus(info);
    } catch (e) {
      // Non-fatal: cached state stays until next successful fetch
    }
  }

  /// Called by PartnerGrantService when the grant snapshot changes.
  /// Re-evaluates effective tier and notifies all listeners.
  static void notifyPartnerGrantChanged() {
    _premiumStatusController.add(isPremium);
  }

  /// Check and refresh premium status
  static Future<bool> checkPremiumStatus() async {
    if (!_isInitialized) return false;

    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(_customerInfo!);
      return _isPremium;
    } catch (e) {
      await LoggerService.error('❌ Failed to check premium status: $e');
      return _isPremium;
    }
  }

  /// Fetch available subscription offerings from RevenueCat
  static Future<Offerings?> fetchOfferings() async {
    if (!_isInitialized) return null;

    try {
      _offerings = await Purchases.getOfferings();
      await LoggerService.info('📦 Fetched ${_offerings?.all.length ?? 0} offerings');
      return _offerings;
    } catch (e) {
      await LoggerService.error('❌ Failed to fetch offerings: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  /// Returns true if purchase was successful
  static Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;

    try {
      await LoggerService.info('Purchasing package: ${package.identifier}');
      unawaited(LoggerService.logEvent('purchase_start', parameters: {
        'package_id': package.identifier,
      }));

      final result = await Purchases.purchasePackage(package);

      // Determine the purchased tier from the package identifier and apply
      // it immediately — entitlements from RevenueCat may still show a
      // previously-cancelled higher tier as active (sandbox lag).
      final pid = package.identifier;
      final String purchasedTier;
      if (pid == pkgClubMonthly || pid == pkgClubAnnual) {
        purchasedTier = 'club';
      } else if (pid == pkgEliteMonthly || pid == pkgEliteAnnual) {
        purchasedTier = 'elite';
      } else {
        purchasedTier = 'pro';
      }
      _purchasedTierOverride = purchasedTier;
      _updatePremiumStatus(result);

      if (isPremium) {
        await LoggerService.info('Purchase successful - Tier: $currentTier');
        unawaited(LoggerService.logEvent('purchase_success', parameters: {
          'package_id': package.identifier,
          'tier': currentTier,
        }));
        unawaited(LoggerService.setUserProperties(tier: currentTier));
        return true;
      } else {
        await LoggerService.warning('Purchase completed but premium not activated');
        return false;
      }
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        await LoggerService.info('Purchase cancelled by user');
        unawaited(LoggerService.logEvent('purchase_cancelled', parameters: {
          'package_id': package.identifier,
        }));
      } else {
        await LoggerService.error('Purchase failed', e, StackTrace.current);
        unawaited(LoggerService.logEvent('purchase_error', parameters: {
          'package_id': package.identifier,
          'error': e.toString(),
        }));
      }
      return false;
    } catch (e) {
      // RevenueCat throws PlatformException for user cancellations
      if (e is PlatformException &&
          (e.details is Map && e.details['userCancelled'] == true)) {
        await LoggerService.info('Purchase cancelled by user');
        unawaited(LoggerService.logEvent('purchase_cancelled', parameters: {
          'package_id': package.identifier,
        }));
      } else {
        await LoggerService.error('Purchase error', e, StackTrace.current);
      }
      return false;
    }
  }

  /// Restore previous purchases
  /// Returns true if restoration resulted in premium access
  static Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;

    try {
      await LoggerService.info('Restoring purchases...');
      unawaited(LoggerService.logEvent('restore_start'));

      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);

      if (isPremium) {
        await LoggerService.info('Purchases restored - Tier: $currentTier');
        unawaited(LoggerService.logEvent('restore_success', parameters: {
          'tier': currentTier,
        }));
        return true;
      } else {
        await LoggerService.info('No active purchases found to restore');
        return false;
      }
    } catch (e) {
      await LoggerService.error('Restore purchases failed', e, StackTrace.current);
      return false;
    }
  }

  /// Log in with a user ID (for cross-device sync)
  /// Call this after user signs in to your app
  static Future<void> loginUser(String userId) async {
    if (!_isInitialized) return;

    try {
      final result = await Purchases.logIn(userId);
      _updatePremiumStatus(result.customerInfo);
      await LoggerService.info('✅ RevenueCat user logged in: $userId');
    } catch (e) {
      await LoggerService.error('❌ RevenueCat login failed: $e');
    }
  }

  /// Log out current user
  /// Call this when user signs out of your app
  static Future<void> logoutUser() async {
    // Clear debug/purchase overrides so the next user starts fresh
    _debugTierOverride = null;
    _purchasedTierOverride = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_debugTierOverrideKey);
    } catch (_) {}

    if (!_isInitialized) return;

    try {
      final customerInfo = await Purchases.logOut();
      _updatePremiumStatus(customerInfo);
      await LoggerService.info('✅ RevenueCat user logged out');
    } catch (e) {
      await LoggerService.error('❌ RevenueCat logout failed: $e');
    }
  }


  /// Format price for display
  static String formatPrice(Package package) {
    final product = package.storeProduct;
    return product.priceString;
  }

  /// Get subscription period description
  static String getPeriodDescription(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return 'per month';
      case PackageType.annual:
        return 'per year';
      case PackageType.weekly:
        return 'per week';
      case PackageType.lifetime:
        return 'one-time';
      default:
        return '';
    }
  }

  /// Dispose of resources
  static void dispose() {
    _premiumStatusController.close();
  }
}
