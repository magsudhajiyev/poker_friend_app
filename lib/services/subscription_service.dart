import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart' show Offering, Offerings, Package, PackageType;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import 'logger_service.dart';
import 'partner_grant_service.dart';
import 'revenuecat_client.dart';
import 'subscription_logic.dart' as logic;

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

  /// The RevenueCat SDK wrapper. Swappable in tests via [debugSetClient].
  static RevenueCatClient _client = LiveRevenueCatClient();

  /// Test-only: inject a fake client. Resets initialization state.
  @visibleForTesting
  static void debugSetClient(RevenueCatClient client) {
    _client = client;
    _isInitialized = false;
    _isPremium = _isElite = _isClub = false;
    _proEntitlements = TierEntitlements.empty;
    _purchasedTierOverride = null;
    _debugTierOverride = null;
    _offerings = null;
  }

  // Cached subscription state
  static bool _isPremium = false;
  static bool _isElite = false;
  static bool _isClub = false;
  static TierEntitlements _proEntitlements = TierEntitlements.empty;
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
  static String get currentTier => logic.resolveCurrentTier(
        proActive: _isPremium,
        eliteActive: _isElite,
        clubActive: _isClub,
        purchasedOverride: _purchasedTierOverride,
      );

  /// Effective tier — applies debug override first, then partner grant.
  /// Partner grant only wins if it provides a HIGHER tier than RevenueCat.
  static String get _effectiveTier => logic.resolveEffectiveTier(
        rcTier: currentTier,
        debugOverride: _debugTierOverride,
        partnerTier: PartnerGrantService.partnerTier,
      );

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

  /// Look up a package by its identifier in the default offering. Matching
  /// (exact + pro alias + store-product-id fallback) lives in the pure,
  /// tested [logic.matchPackageId]. Returns null if not found on this platform.
  static Package? packageById(String identifier) {
    final packages = defaultOffering?.availablePackages ?? [];
    final refs = packages
        .map((p) => logic.PackageRef(p.identifier, p.storeProduct.identifier))
        .toList();
    final i = logic.matchPackageId(identifier, refs);
    return i >= 0 ? packages[i] : null;
  }

  // Package identifier constants — must match RevenueCat dashboard
  // (re-exported from subscription_logic so existing callers keep working).
  static const String pkgProMonthly = logic.kPkgProMonthly;
  static const String pkgProAnnual = logic.kPkgProAnnual;
  static const String pkgEliteMonthly = logic.kPkgEliteMonthly;
  static const String pkgEliteAnnual = logic.kPkgEliteAnnual;
  static const String pkgClubMonthly = logic.kPkgClubMonthly;
  static const String pkgClubAnnual = logic.kPkgClubAnnual;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Whether the service has been initialized
  static bool get isInitialized => _isInitialized;

  /// The current 'pro' entitlement snapshot (active flag, whether it's a
  /// promotional grant, and its expiry) — used by the launch-promo flow.
  /// Null-safe: returns the last snapshot, [TierEntitlements.empty] until set.
  static TierEntitlements get proEntitlement => _proEntitlements;

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

      await _client.configure(apiKey);
      await _configuredInit();
      await LoggerService.info('✅ RevenueCat initialized - Tier: $currentTier');
    } catch (e) {
      await LoggerService.error('❌ RevenueCat initialization failed: $e');
      // Continue without subscriptions - features will be unlocked in demo mode
      _isInitialized = true;
    }
  }

  /// The post-configure init flow, shared by [initialize] and the test entry.
  ///
  /// NOTE: preserves the original ordering exactly — `fetchOfferings()` runs
  /// while `_isInitialized` is still false, so it no-ops here (offerings load
  /// on the paywall's later explicit call). This is a pre-existing quirk kept
  /// intentionally so this refactor introduces zero behavior change; fixing it
  /// (init before fetch) is a separate follow-up.
  static Future<void> _configuredInit() async {
    // Listen for customer info updates (subscription changes)
    _client.addCustomerInfoUpdateListener(_updatePremiumStatus);
    // Get initial entitlements
    _updatePremiumStatus(await _client.getEntitlements());
    // Fetch offerings (no-ops until _isInitialized — see note above)
    await fetchOfferings();
    _isInitialized = true;
  }

  /// Test-only: initialize with an already-injected fake client, skipping the
  /// Platform/env-key gate that isn't available in the VM test environment.
  @visibleForTesting
  static Future<void> debugInitializeWithClient(RevenueCatClient client) async {
    _client = client;
    _isInitialized = false;
    _purchasedTierOverride = null;
    _debugTierOverride = null;
    await client.configure('test-key');
    await _configuredInit();
  }

  /// Update premium status from an entitlement snapshot.
  static void _updatePremiumStatus(TierEntitlements ents) {
    _proEntitlements = ents;
    final prevTier = currentTier;
    _isPremium = ents.proActive;
    _isElite = ents.eliteActive;
    _isClub = ents.clubActive;

    // Clear the purchased-tier override once entitlements match or exceed it.
    // e.g. after buying Pro: override='pro', entitlements show pro=active → clear.
    final entitlementTier = logic.resolveCurrentTier(
      proActive: _isPremium,
      eliteActive: _isElite,
      clubActive: _isClub,
    );
    if (logic.shouldClearPurchaseOverride(
      purchasedOverride: _purchasedTierOverride,
      entitlementTier: entitlementTier,
    )) {
      _purchasedTierOverride = null;
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
      await _client.invalidateCustomerInfoCache();
      // Clear purchase override so fresh entitlements are authoritative
      _purchasedTierOverride = null;
      _updatePremiumStatus(await _client.getEntitlements());
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
      _updatePremiumStatus(await _client.getEntitlements());
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
      _offerings = await _client.getOfferings();
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

    await LoggerService.info('Purchasing package: ${package.identifier}');
    unawaited(LoggerService.logEvent('purchase_start', parameters: {
      'package_id': package.identifier,
    }));

    final outcome = await _client.purchasePackage(package);

    if (outcome.cancelled) {
      await LoggerService.info('Purchase cancelled by user');
      unawaited(LoggerService.logEvent('purchase_cancelled', parameters: {
        'package_id': package.identifier,
      }));
      return false;
    }
    if (outcome.error != null || outcome.entitlements == null) {
      await LoggerService.error(
          'Purchase failed', outcome.error, StackTrace.current);
      unawaited(LoggerService.logEvent('purchase_error', parameters: {
        'package_id': package.identifier,
        'error': outcome.error?.toString() ?? 'no entitlements',
      }));
      return false;
    }

    // Apply the purchased tier immediately — entitlements from RevenueCat may
    // still show a previously-cancelled higher tier as active (sandbox lag).
    _purchasedTierOverride =
        logic.tierForPurchasedPackageId(package.identifier);
    _updatePremiumStatus(outcome.entitlements!);

    if (isPremium) {
      await LoggerService.info('Purchase successful - Tier: $currentTier');
      unawaited(LoggerService.logEvent('purchase_success', parameters: {
        'package_id': package.identifier,
        'tier': currentTier,
      }));
      unawaited(LoggerService.setUserProperties(tier: currentTier));
      return true;
    }
    await LoggerService.warning('Purchase completed but premium not activated');
    return false;
  }

  /// Restore previous purchases
  /// Returns true if restoration resulted in premium access
  static Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;

    try {
      await LoggerService.info('Restoring purchases...');
      unawaited(LoggerService.logEvent('restore_start'));

      _updatePremiumStatus(await _client.restorePurchases());

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
      _updatePremiumStatus(await _client.logIn(userId));
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
      _updatePremiumStatus(await _client.logOut());
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
