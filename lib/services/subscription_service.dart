import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/env_config.dart';
import 'logger_service.dart';

/// Service for managing subscriptions via RevenueCat
///
/// Usage:
/// - Call `SubscriptionService.initialize()` in main.dart after Firebase init
/// - Check `SubscriptionService.isPremium` to gate features
/// - Use `SubscriptionService.showPaywall()` to display subscription options
class SubscriptionService {
  // API keys loaded from .env via EnvConfig
  static String get _iosApiKey => EnvConfig.revenueCatIosApiKey;
  static String get _androidApiKey => EnvConfig.revenueCatAndroidApiKey;

  // Entitlement identifier - must match RevenueCat dashboard
  static const String premiumEntitlement = 'premium';

  // Cached subscription state
  static bool _isPremium = false;
  static CustomerInfo? _customerInfo;
  static Offerings? _offerings;
  static bool _isInitialized = false;

  // Stream controller for subscription status changes
  static final _premiumStatusController = StreamController<bool>.broadcast();

  /// Stream of premium status changes
  static Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  /// Whether the user has an active premium subscription
  static bool get isPremium => _isPremium;

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
      await LoggerService.info('✅ RevenueCat initialized - Premium: $_isPremium');
    } catch (e) {
      await LoggerService.error('❌ RevenueCat initialization failed: $e');
      // Continue without subscriptions - features will be unlocked in demo mode
      _isInitialized = true;
    }
  }

  /// Update premium status from customer info
  static void _updatePremiumStatus(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;
    final hadPremium = _isPremium;
    _isPremium = customerInfo.entitlements.all[premiumEntitlement]?.isActive ?? false;

    if (hadPremium != _isPremium) {
      _premiumStatusController.add(_isPremium);
    }
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

  /// Get the current (default) offering
  static Offering? get currentOffering => _offerings?.current;

  /// Get all available packages from current offering
  static List<Package> get availablePackages => currentOffering?.availablePackages ?? [];

  /// Purchase a subscription package
  /// Returns true if purchase was successful
  static Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;

    try {
      await LoggerService.info('🛒 Purchasing package: ${package.identifier}');

      final result = await Purchases.purchasePackage(package);
      _updatePremiumStatus(result.customerInfo);

      if (_isPremium) {
        await LoggerService.info('✅ Purchase successful - Premium activated');
        return true;
      } else {
        await LoggerService.warning('⚠️ Purchase completed but premium not activated');
        return false;
      }
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        await LoggerService.info('ℹ️ Purchase cancelled by user');
      } else {
        await LoggerService.error('❌ Purchase failed: $e');
      }
      return false;
    } catch (e) {
      await LoggerService.error('❌ Purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases
  /// Returns true if restoration resulted in premium access
  static Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;

    try {
      await LoggerService.info('🔄 Restoring purchases...');

      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);

      if (_isPremium) {
        await LoggerService.info('✅ Purchases restored - Premium activated');
        return true;
      } else {
        await LoggerService.info('ℹ️ No active purchases found to restore');
        return false;
      }
    } catch (e) {
      await LoggerService.error('❌ Restore purchases failed: $e');
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
