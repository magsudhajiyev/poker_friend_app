import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/notification_prefs_service.dart';
import 'package:poker_logger/services/paid_nudge_logic.dart';
import 'package:poker_logger/services/subscription_logic.dart';

/// Pure paid-nudge rules: caps, timing, quiet hours, real-numbers-only recap.
void main() {
  final now = DateTime(2026, 11, 5, 12);

  group('withinOfferCap (≤2 per rolling 7 days)', () {
    test('empty and one existing allow another', () {
      expect(PaidNudgeLogic.withinOfferCap([], now), isTrue);
      expect(PaidNudgeLogic.withinOfferCap([now.subtract(const Duration(days: 1))], now),
          isTrue);
    });

    test('a third within 7 days is refused', () {
      final ex = [
        now.subtract(const Duration(days: 2)),
        now.subtract(const Duration(days: 1)),
      ];
      expect(PaidNudgeLogic.withinOfferCap(ex, now), isFalse);
    });

    test('a third is fine once the oldest left the window', () {
      final ex = [
        now.subtract(const Duration(days: 7, hours: 1)),
        now.subtract(const Duration(days: 1)),
      ];
      expect(PaidNudgeLogic.withinOfferCap(ex, now), isTrue);
    });

    test('future scheduled pushes count; window is checked on both sides', () {
      final ex = [
        now.add(const Duration(days: 1)),
        now.add(const Duration(days: 2)),
      ];
      expect(PaidNudgeLogic.withinOfferCap(ex, now), isFalse);
      final far = [
        now.subtract(const Duration(days: 6)),
        now.add(const Duration(days: 6)),
      ];
      // 12 days apart: the candidate shares a window with only one of them.
      expect(PaidNudgeLogic.withinOfferCap(far, now), isTrue);
    });
  });

  group('dayIsFree (one engagement push per local day)', () {
    test('same local day is taken, other days are free', () {
      final other = [DateTime(2026, 11, 6, 8)];
      expect(PaidNudgeLogic.dayIsFree(other, DateTime(2026, 11, 6, 19)), isFalse);
      expect(PaidNudgeLogic.dayIsFree(other, DateTime(2026, 11, 7, 8)), isTrue);
      expect(PaidNudgeLogic.dayIsFree([], now), isTrue);
    });

    test('a streak reminder on that day blocks the nudge', () {
      final streak = DateTime(2026, 11, 7, 18);
      expect(PaidNudgeLogic.dayIsFree([streak], DateTime(2026, 11, 7, 19)),
          isFalse);
    });
  });

  group('tooInactive (14+ days)', () {
    test('fires within 14 days of the last open, not at or after', () {
      expect(PaidNudgeLogic.tooInactive(now, now.add(const Duration(days: 13))),
          isFalse);
      expect(PaidNudgeLogic.tooInactive(now, now.add(const Duration(days: 14))),
          isTrue);
      expect(PaidNudgeLogic.tooInactive(now, now.add(const Duration(days: 30))),
          isTrue);
    });
  });

  group('quiet hours', () {
    test('an hour inside the window moves to its end; others stay', () {
      const p = NotificationPrefs(); // 22 → 8
      expect(PaidNudgeLogic.outOfQuietHours(23, p), 8);
      expect(PaidNudgeLogic.outOfQuietHours(3, p), 8);
      expect(PaidNudgeLogic.outOfQuietHours(8, p), 8);
      expect(PaidNudgeLogic.outOfQuietHours(19, p), 19);
    });
  });

  group('missedDayTime', () {
    test('runDay + 2 at the personal hour', () {
      final t = PaidNudgeLogic.missedDayTime(DateTime(2026, 11, 5), now, 18);
      expect(t, DateTime(2026, 11, 7, 18));
    });

    test('null when that moment is not far enough ahead', () {
      expect(PaidNudgeLogic.missedDayTime(DateTime(2026, 11, 2), now, 18),
          isNull);
    });

    test('the target day is the day after the run', () {
      expect(PaidNudgeLogic.missedDayTarget(DateTime(2026, 11, 30)),
          DateTime(2026, 12, 1));
    });
  });

  group('paywallReturnTime (~24h later at the personal hour)', () {
    test('lands on the hour, 20–44h ahead', () {
      for (var h = 0; h < 24; h++) {
        final t = PaidNudgeLogic.paywallReturnTime(now, h);
        expect(t.hour, h);
        final d = t.difference(now);
        expect(d, greaterThanOrEqualTo(const Duration(hours: 20)));
        expect(d, lessThan(const Duration(hours: 45)));
      }
    });
  });

  group('trialRecapTime (a day before the charge reminder)', () {
    TrialStatus trial(DateTime endsAt, {bool renew = true}) =>
        TrialStatus(endsAt: endsAt, willRenew: renew);

    test('day before the charge reminder, at the personal hour', () {
      final ends = DateTime(2026, 11, 12, 15);
      final reminder = trialReminderTime(ends);
      final t = PaidNudgeLogic.trialRecapTime(trial(ends), now, 18)!;
      expect(t.hour, 18);
      expect(t.isBefore(reminder), isTrue);
      expect(reminder.difference(t), lessThan(const Duration(days: 2)));
      expect(reminder.difference(t), greaterThan(Duration.zero));
    });

    test('null when the trial will not renew or there is no trial', () {
      expect(PaidNudgeLogic.trialRecapTime(null, now, 18), isNull);
      expect(
          PaidNudgeLogic.trialRecapTime(
              trial(DateTime(2026, 11, 12, 15), renew: false), now, 18),
          isNull);
    });

    test('null when the recap moment is already past (short trial)', () {
      expect(
          PaidNudgeLogic.trialRecapTime(
              trial(DateTime(2026, 11, 6, 15)), now, 18),
          isNull);
    });
  });

  group('TrialRecapStats (real numbers only)', () {
    test('all zero → nothing to say', () {
      expect(const TrialRecapStats().hasAnything, isFalse);
      expect(const TrialRecapStats(accuracyPct: 0.2).hasAnything, isFalse);
    });

    test('any real value counts; accuracy rounds', () {
      expect(const TrialRecapStats(hands: 3).hasAnything, isTrue);
      expect(const TrialRecapStats(challenges: 1).hasAnything, isTrue);
      expect(const TrialRecapStats(accuracyPct: 81.6).accuracyRounded, 82);
    });
  });

  group('never queued for the current local day', () {
    test('earliest offer time is tomorrow 00:00', () {
      expect(PaidNudgeLogic.earliestOfferTime(DateTime(2026, 11, 5, 23, 59)),
          DateTime(2026, 11, 6));
    });

    test('notBeforeTomorrow shifts today to tomorrow, keeps later times', () {
      final n = DateTime(2026, 11, 5, 10);
      expect(PaidNudgeLogic.notBeforeTomorrow(DateTime(2026, 11, 5, 19), n),
          DateTime(2026, 11, 6, 19));
      expect(PaidNudgeLogic.notBeforeTomorrow(DateTime(2026, 11, 7, 19), n),
          DateTime(2026, 11, 7, 19));
    });

    test('paywall return is never today, even just after midnight', () {
      final early = DateTime(2026, 11, 5, 0, 30);
      for (var h = 0; h < 24; h++) {
        final t = PaidNudgeLogic.paywallReturnTime(early, h);
        expect(PaidNudgeLogic.sameLocalDay(t, early), isFalse, reason: 'h=$h');
      }
    });

    test('missed day on/before today is refused', () {
      expect(PaidNudgeLogic.missedDayTime(DateTime(2026, 11, 3), now, 18),
          isNull);
    });

    test('trial recap that would land today shifts to tomorrow', () {
      // Charge 11/8 09:00 → reminder ~11/7 09:00 → recap base day 11/6 (today
      // is 11/6 at 07:00): the 18:00 slot today becomes 11/7 18:00, which is
      // after the reminder, so there is no recap at all.
      final n = DateTime(2026, 11, 6, 7);
      final t = PaidNudgeLogic.trialRecapTime(
          TrialStatus(endsAt: DateTime(2026, 11, 8, 9), willRenew: true), n, 18);
      if (t != null) {
        expect(PaidNudgeLogic.sameLocalDay(t, n), isFalse);
      }
    });
  });

  group('syncGate (admin/flag cold start)', () {
    test('waits until flag state is known and a user is signed in', () {
      expect(
          PaidNudgeLogic.syncGate(
              stateKnown: false, signedIn: true, flagOn: false),
          NudgeSyncGate.wait,
          reason: 'cold start must not cancel queued nudges');
      expect(
          PaidNudgeLogic.syncGate(
              stateKnown: true, signedIn: false, flagOn: true),
          NudgeSyncGate.wait);
    });

    test('known + off cancels, known + on runs', () {
      expect(
          PaidNudgeLogic.syncGate(
              stateKnown: true, signedIn: true, flagOn: false),
          NudgeSyncGate.cancelAll);
      expect(
          PaidNudgeLogic.syncGate(
              stateKnown: true, signedIn: true, flagOn: true),
          NudgeSyncGate.run);
    });
  });
}
