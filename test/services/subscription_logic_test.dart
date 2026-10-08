import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/subscription_logic.dart';

/// Pure subscription decision logic — the part that actually breaks on a
/// RevenueCat version bump. These must pass on 8.11 BEFORE the 9.x bump, so
/// any failure after the bump points at the SDK adaptation, not the logic.
void main() {
  group('resolveCurrentTier', () {
    test('maps active flags with club > elite > pro > free precedence', () {
      String t(bool p, bool e, bool c) => resolveCurrentTier(
          proActive: p, eliteActive: e, clubActive: c);
      expect(t(false, false, false), 'free');
      expect(t(true, false, false), 'pro');
      expect(t(true, true, false), 'elite'); // elite outranks pro
      expect(t(true, true, true), 'club'); // club outranks all
      expect(t(false, false, true), 'club');
      expect(t(false, true, false), 'elite');
    });

    test('purchased override wins over entitlement flags', () {
      expect(
        resolveCurrentTier(
            proActive: false,
            eliteActive: false,
            clubActive: false,
            purchasedOverride: 'elite'),
        'elite',
      );
      // Even when entitlements already show a higher tier, the override is
      // returned verbatim (clearing is a separate concern).
      expect(
        resolveCurrentTier(
            proActive: true,
            eliteActive: true,
            clubActive: true,
            purchasedOverride: 'pro'),
        'pro',
      );
    });
  });

  group('resolveEffectiveTier', () {
    test('debug override wins outright', () {
      expect(
        resolveEffectiveTier(
            rcTier: 'free', debugOverride: 'club', partnerTier: 'pro'),
        'club',
      );
    });

    test('no partner grant → rc tier', () {
      expect(resolveEffectiveTier(rcTier: 'pro'), 'pro');
      expect(resolveEffectiveTier(rcTier: 'free', partnerTier: null), 'free');
    });

    test('partner grant only wins when strictly higher', () {
      // Higher → partner wins
      expect(resolveEffectiveTier(rcTier: 'free', partnerTier: 'elite'), 'elite');
      expect(resolveEffectiveTier(rcTier: 'pro', partnerTier: 'club'), 'club');
      // Equal → rc kept
      expect(resolveEffectiveTier(rcTier: 'elite', partnerTier: 'elite'), 'elite');
      // Lower → rc kept (never downgrades a real purchase)
      expect(resolveEffectiveTier(rcTier: 'club', partnerTier: 'pro'), 'club');
    });
  });

  group('shouldClearPurchaseOverride', () {
    test('null override → never clears', () {
      expect(
        shouldClearPurchaseOverride(
            purchasedOverride: null, entitlementTier: 'club'),
        isFalse,
      );
    });

    test('clears once entitlements catch up to or exceed the override', () {
      // Just bought pro; entitlement now shows pro → clear.
      expect(
        shouldClearPurchaseOverride(
            purchasedOverride: 'pro', entitlementTier: 'pro'),
        isTrue,
      );
      // Bought pro, entitlement shows elite (higher) → clear.
      expect(
        shouldClearPurchaseOverride(
            purchasedOverride: 'pro', entitlementTier: 'elite'),
        isTrue,
      );
    });

    test('keeps override while entitlements still lag behind', () {
      // Bought club, entitlement still only shows pro (sandbox lag) → keep.
      expect(
        shouldClearPurchaseOverride(
            purchasedOverride: 'club', entitlementTier: 'pro'),
        isFalse,
      );
      expect(
        shouldClearPurchaseOverride(
            purchasedOverride: 'elite', entitlementTier: 'free'),
        isFalse,
      );
    });
  });

  group('tierForPurchasedPackageId', () {
    test('maps all 6 package ids to tiers', () {
      expect(tierForPurchasedPackageId(kPkgProMonthly), 'pro');
      expect(tierForPurchasedPackageId(kPkgProAnnual), 'pro');
      expect(tierForPurchasedPackageId(kPkgEliteMonthly), 'elite');
      expect(tierForPurchasedPackageId(kPkgEliteAnnual), 'elite');
      expect(tierForPurchasedPackageId(kPkgClubMonthly), 'club');
      expect(tierForPurchasedPackageId(kPkgClubAnnual), 'club');
    });

    test('unknown id defaults to pro', () {
      expect(tierForPurchasedPackageId('mystery_package'), 'pro');
    });
  });

  group('matchPackageId', () {
    List<PackageRef> pkgs() => const [
          PackageRef(r'$rc_monthly', 'pro:monthly'),
          PackageRef(r'$rc_annual', 'pro:annual'),
          PackageRef('elite_monthly', 'elite:monthly'),
          PackageRef('club_annual', 'club:annual'),
        ];

    test('exact identifier match', () {
      expect(matchPackageId('elite_monthly', pkgs()), 2);
      expect(matchPackageId(r'$rc_annual', pkgs()), 1);
    });

    test('pro alias: pro_monthly/pro_annual resolve to standard packages', () {
      // This is the fix that prevented USD fallback on non-USD storefronts.
      expect(matchPackageId('pro_monthly', pkgs()), 0);
      expect(matchPackageId('pro_annual', pkgs()), 1);
    });

    test('store-product-id fallback with _ → : normalization', () {
      // No identifier match, but store product id matches after normalize.
      final custom = [const PackageRef('weird_id', 'elite:monthly')];
      expect(matchPackageId('elite_monthly', custom), 0);
    });

    test('no match → -1', () {
      expect(matchPackageId('nonexistent', pkgs()), -1);
    });
  });
}
