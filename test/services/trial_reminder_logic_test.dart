import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/subscription_logic.dart';

/// Hard paywall step 4: when the "your free trial ends tomorrow" reminder
/// fires. Rule: 24 h before the first charge; if that lands in quiet hours
/// (22:00–09:00 local) move it EARLIER to 19:00 — never later, so the user
/// always has at least 24 h to cancel.
void main() {
  // All times are LOCAL (the function works on local wall-clock time).
  DateTime at(int d, int h, [int m = 0]) => DateTime(2026, 10, d, h, m);

  group('trialReminderTime', () {
    test('daytime: exactly 24 h before the charge', () {
      expect(trialReminderTime(at(29, 15)), at(28, 15));
    });

    test('late evening (≥22:00) → 19:00 the same evening', () {
      expect(trialReminderTime(at(29, 23, 30)), at(28, 19));
      expect(trialReminderTime(at(29, 22)), at(28, 19));
    });

    test('early morning (<09:00) → 19:00 the evening before', () {
      expect(trialReminderTime(at(29, 3)), at(27, 19));
      expect(trialReminderTime(at(29, 8, 59)), at(27, 19));
    });

    test('09:00 and 21:59 are not quiet hours', () {
      expect(trialReminderTime(at(29, 9)), at(28, 9));
      expect(trialReminderTime(at(29, 21, 59)), at(28, 21, 59));
    });

    test('never later than 24 h before the charge', () {
      for (var h = 0; h < 24; h++) {
        final end = at(29, h, 30);
        final r = trialReminderTime(end);
        expect(end.difference(r) >= const Duration(hours: 24), isTrue,
            reason: 'charge at $end, reminder at $r');
      }
    });
  });

  group('decideTrialReminder', () {
    final now = at(22, 12);
    TrialStatus trial(DateTime end, {bool renew = true}) =>
        TrialStatus(endsAt: end, willRenew: renew);

    test('active renewing trial → schedule at the reminder time', () {
      final d = decideTrialReminder(trial(at(29, 15)), now);
      expect(d.action, TrialReminderAction.schedule);
      expect(d.at, at(28, 15));
      expect(d.endsAtMs, at(29, 15).millisecondsSinceEpoch);
    });

    test('no trial / cancelled trial → cancel any queued reminder', () {
      expect(decideTrialReminder(null, now).action, TrialReminderAction.cancel);
      expect(decideTrialReminder(trial(at(29, 15), renew: false), now).action,
          TrialReminderAction.cancel);
    });

    test('reminder moment already passed but charge still ahead → '
        'show it NOW (a late reminder beats none)', () {
      final d = decideTrialReminder(trial(at(23, 2)), now); // 14 h left
      expect(d.action, TrialReminderAction.showNow);
    });

    test('less than 2 h left → nothing (too late to be useful)', () {
      final d = decideTrialReminder(trial(at(22, 13)), now);
      expect(d.action, TrialReminderAction.cancel);
    });
  });

  group('matchEntitlementPackage (price for the reminder)', () {
    const refs = [
      PackageRef(r'$rc_monthly', 'pro:monthly'),
      PackageRef(r'$rc_annual', 'pro:annual'),
      PackageRef('elite_monthly', 'elite_monthly'),
      PackageRef('elite_annual', 'elite_annual'),
    ];
    test('Android: subscription id + base plan id', () {
      expect(matchEntitlementPackage('pro', 'annual', refs), 1);
      expect(matchEntitlementPackage('pro', 'monthly', refs), 0);
    });
    test('iOS: product id equals the store product', () {
      expect(matchEntitlementPackage('elite_annual', null, refs), 3);
    });
    test('unknown / missing → -1', () {
      expect(matchEntitlementPackage(null, null, refs), -1);
      expect(matchEntitlementPackage('club', 'annual', refs), -1);
      // Android id without a plan can't pick monthly vs annual safely.
      expect(matchEntitlementPackage('pro', null, refs), -1);
    });
  });
}
