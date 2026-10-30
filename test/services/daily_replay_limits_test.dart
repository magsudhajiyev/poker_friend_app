import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_challenge_service.dart';
import 'package:poker_logger/services/daily_replay_limits.dart';
import 'package:poker_logger/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure tier-window logic for Daily Challenge replays. The tier is driven by
/// SubscriptionService's debug override so these tests don't need RevenueCat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 12, 1); // well after the epoch (2026-10-14)
  final epoch = DailyChallengeService.epoch; // 2026-10-14

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await SubscriptionService.setDebugTierOverride(null);
  });

  Future<void> asTier(String? tier) =>
      SubscriptionService.setDebugTierOverride(tier);

  adminPreviewTests();

  group('replayWindowDays', () {
    test('free = 0 (no replays)', () async {
      await asTier(null);
      expect(DailyReplayLimits.replayWindowDays(), 0);
      expect(DailyReplayLimits.canReplayAny, isFalse);
    });

    test('pro = 15 days', () async {
      await asTier('pro');
      expect(DailyReplayLimits.replayWindowDays(), 15);
      expect(DailyReplayLimits.canReplayAny, isTrue);
    });

    test('elite = unlimited (null)', () async {
      await asTier('elite');
      expect(DailyReplayLimits.replayWindowDays(), isNull);
    });

    test('club = unlimited (null)', () async {
      await asTier('club');
      expect(DailyReplayLimits.replayWindowDays(), isNull);
    });
  });

  group('isReplayable', () {
    test('free cannot replay anything', () async {
      await asTier(null);
      expect(DailyReplayLimits.isReplayable(
          today.subtract(const Duration(days: 1)), today), isFalse);
    });

    test('today and future are never replayable (even for Elite)', () async {
      await asTier('elite');
      expect(DailyReplayLimits.isReplayable(today, today), isFalse);
      expect(DailyReplayLimits.isReplayable(
          today.add(const Duration(days: 1)), today), isFalse);
    });

    test('pro: within 15 days replayable, 16+ locked', () async {
      await asTier('pro');
      // yesterday … 15 days ago inclusive are in-window.
      expect(DailyReplayLimits.isReplayable(
          today.subtract(const Duration(days: 1)), today), isTrue);
      expect(DailyReplayLimits.isReplayable(
          today.subtract(const Duration(days: 15)), today), isTrue);
      // 16 days ago is out of the Pro window.
      expect(DailyReplayLimits.isReplayable(
          today.subtract(const Duration(days: 16)), today), isFalse);
    });

    test('elite: anything back to epoch is replayable', () async {
      await asTier('elite');
      expect(DailyReplayLimits.isReplayable(epoch, today), isTrue);
      expect(DailyReplayLimits.isReplayable(
          epoch.subtract(const Duration(days: 1)), today), isFalse); // pre-epoch
    });
  });

  group('isLockedByTier', () {
    test('pro: a 20-days-ago day is locked (upsell), not simply gone',
        () async {
      await asTier('pro');
      final day = today.subtract(const Duration(days: 20));
      expect(DailyReplayLimits.isReplayable(day, today), isFalse);
      expect(DailyReplayLimits.isLockedByTier(day, today), isTrue);
    });

    test('elite: nothing in range is locked', () async {
      await asTier('elite');
      final day = today.subtract(const Duration(days: 30));
      expect(DailyReplayLimits.isLockedByTier(day, today), isFalse);
    });

    test('free: past in-epoch days are locked (upsell to paid)', () async {
      await asTier(null);
      final day = today.subtract(const Duration(days: 2));
      expect(DailyReplayLimits.isLockedByTier(day, today), isTrue);
    });

    test('pre-epoch days are not "locked by tier" (just out of range)',
        () async {
      await asTier('pro');
      final day = epoch.subtract(const Duration(days: 5));
      expect(DailyReplayLimits.isLockedByTier(day, today), isFalse);
    });
  });

  group('earliestReplayDay', () {
    test('free = null', () async {
      await asTier(null);
      expect(DailyReplayLimits.earliestReplayDay(today), isNull);
    });

    test('pro = today - 15 days (when after epoch)', () async {
      await asTier('pro');
      expect(DailyReplayLimits.earliestReplayDay(today),
          DateTime(2026, 11, 16)); // 2026-12-01 minus 15
    });

    test('pro window clamps to epoch when it would precede it', () async {
      await asTier('pro');
      final earlyToday = DateTime(2026, 10, 20); // only 6 days after epoch
      expect(DailyReplayLimits.earliestReplayDay(earlyToday),
          DailyChallengeService.dateOnly(epoch));
    });

    test('elite = epoch', () async {
      await asTier('elite');
      expect(DailyReplayLimits.earliestReplayDay(today),
          DailyChallengeService.dateOnly(epoch));
    });

    test('pro window crosses year rollover, leap day, and DST dates', () async {
      await asTier('pro');
      expect(DailyReplayLimits.earliestReplayDay(DateTime(2027, 1, 5)),
          DateTime(2026, 12, 21));
      expect(DailyReplayLimits.earliestReplayDay(DateTime(2028, 3, 5)),
          DateTime(2028, 2, 19)); // 2028 is a leap year
      // US spring forward 2027-03-14: midnight-to-midnight is 23h there.
      expect(DailyReplayLimits.earliestReplayDay(DateTime(2027, 3, 20)),
          DateTime(2027, 3, 5));
      expect(DailyReplayLimits.earliestReplayDay(DateTime(2027, 3, 29)),
          DateTime(2027, 3, 14));
    });
  });
}

// Admin early-access gating (pure).
void adminPreviewTests() {
  final today = DateTime(2026, 12, 1);
  group('isPreviewable (admin early access)', () {
    test('admin + scheduled future day is previewable', () {
      expect(
          DailyReplayLimits.isPreviewable(DateTime(2026, 12, 2), today,
              isAdmin: true, hasSchedule: true),
          isTrue);
    });
    test('non-admin future day is never previewable', () {
      expect(
          DailyReplayLimits.isPreviewable(DateTime(2026, 12, 2), today,
              isAdmin: false, hasSchedule: true),
          isFalse);
    });
    test('admin but no schedule -> not previewable', () {
      expect(
          DailyReplayLimits.isPreviewable(DateTime(2026, 12, 2), today,
              isAdmin: true, hasSchedule: false),
          isFalse);
    });
    test('today and past are not previews', () {
      for (final d in [today, DateTime(2026, 11, 30)]) {
        expect(
            DailyReplayLimits.isPreviewable(d, today,
                isAdmin: true, hasSchedule: true),
            isFalse);
      }
    });
    test('beyond horizon is not previewable', () {
      final far = DateTime(2026, 12, 1 + DailyReplayLimits.adminPreviewHorizonDays + 1);
      expect(
          DailyReplayLimits.isPreviewable(far, today,
              isAdmin: true, hasSchedule: true),
          isFalse);
    });
    test('isReplayable is unchanged for future days (even admin tier elite)',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SubscriptionService.setDebugTierOverride('elite');
      expect(DailyReplayLimits.isReplayable(DateTime(2026, 12, 2), today),
          isFalse);
      await SubscriptionService.setDebugTierOverride(null);
    });
  });
}
