import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/subscription_logic.dart';

/// Free-trial state (hard paywall step 2). Store trials: monthly plans 7
/// days, annual plans 1 month — the length always comes from the store, so
/// the logic only trusts the entitlement's period type + expiry.
void main() {
  final now = DateTime.utc(2026, 10, 22, 12);

  group('trialStatusFrom', () {
    test('active trial → end date, renew flag and product', () {
      final s = trialStatusFrom(
        inTrial: true,
        willRenew: true,
        expirationIso: '2026-10-29T12:00:00Z',
        productId: 'pro_monthly',
        now: now,
      )!;
      expect(s.endsAt, DateTime.utc(2026, 10, 29, 12));
      expect(s.willRenew, isTrue);
      expect(s.productId, 'pro_monthly');
    });

    test('not in a trial (normal paid period) → null', () {
      expect(
          trialStatusFrom(
              inTrial: false,
              willRenew: true,
              expirationIso: '2026-10-29T12:00:00Z',
              now: now),
          isNull);
    });

    test('missing / unparsable / past expiry → null', () {
      expect(
          trialStatusFrom(
              inTrial: true, willRenew: true, expirationIso: null, now: now),
          isNull);
      expect(
          trialStatusFrom(
              inTrial: true,
              willRenew: true,
              expirationIso: 'not-a-date',
              now: now),
          isNull);
      expect(
          trialStatusFrom(
              inTrial: true,
              willRenew: true,
              expirationIso: '2026-10-22T11:59:59Z',
              now: now),
          isNull);
    });
  });

  group('freeTrialOffer (store intro offer → what the paywall shows)', () {
    test('1 week (Apple reports weeks) → 7 days', () {
      final t = freeTrialOffer(unit: 'week', count: 1, price: 0)!;
      expect(t.unit, TrialUnit.day);
      expect(t.count, 7);
    });

    test('7 days stays 7 days; 1 month stays 1 month', () {
      expect(freeTrialOffer(unit: 'day', count: 7, price: 0)!.count, 7);
      final m = freeTrialOffer(unit: 'month', count: 1, price: 0)!;
      expect(m.unit, TrialUnit.month);
      expect(m.count, 1);
    });

    test('1 year → 12 months', () {
      final y = freeTrialOffer(unit: 'year', count: 1, price: 0)!;
      expect(y.unit, TrialUnit.month);
      expect(y.count, 12);
    });

    test('a PAID intro price is not a free trial', () {
      expect(freeTrialOffer(unit: 'month', count: 1, price: 0.99), isNull);
    });

    test('unknown unit or non-positive length → null', () {
      expect(freeTrialOffer(unit: 'unknown', count: 1, price: 0), isNull);
      expect(freeTrialOffer(unit: 'day', count: 0, price: 0), isNull);
    });
  });
}
