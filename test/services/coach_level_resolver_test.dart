import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/coach_level_resolver.dart';

/// Experience-level resolution: stats once the sample is big enough,
/// journey self-report as the seed while it is thin. Pure branches only.
void main() {
  group('fromJourney', () {
    test('maps the four onboarding answers to three tiers', () {
      expect(CoachLevelResolver.fromJourney('pro'), CoachLevel.advanced);
      expect(CoachLevelResolver.fromJourney('regular'),
          CoachLevel.intermediate);
      expect(
          CoachLevelResolver.fromJourney('beginner'), CoachLevel.beginner);
      expect(CoachLevelResolver.fromJourney('fun'), CoachLevel.beginner);
    });

    test('missing/unknown journey defaults to beginner', () {
      expect(CoachLevelResolver.fromJourney(null), CoachLevel.beginner);
      expect(
          CoachLevelResolver.fromJourney('nonsense'), CoachLevel.beginner);
    });
  });

  group('fromPlayStyle', () {
    test('solid profiles read as advanced', () {
      for (final s in ['TAG', 'LAG', 'Maniac', 'Balanced']) {
        expect(CoachLevelResolver.fromPlayStyle(s), CoachLevel.advanced,
            reason: s);
      }
    });

    test('developing/passive profiles read as intermediate', () {
      for (final s in [
        'Nit',
        'Calling Station',
        'Tight-Passive',
        'Loose-Passive'
      ]) {
        expect(CoachLevelResolver.fromPlayStyle(s), CoachLevel.intermediate,
            reason: s);
      }
    });

    test('unknown profile reads as beginner', () {
      expect(
          CoachLevelResolver.fromPlayStyle('Unknown'), CoachLevel.beginner);
    });
  });

  group('resolve (stats vs seed boundary)', () {
    test('thin sample uses the journey seed, ignores stats', () {
      // 'pro' journey but only 20 hands — too few to trust stats.
      final level = CoachLevelResolver.resolve(
        pokerJourney: 'pro',
        handsPlayed: 20,
        vpip: 5,
        pfr: 1,
        threeBet: 0,
        aggressionFactor: 0,
      );
      expect(level, CoachLevel.advanced, reason: 'from the pro self-report');
    });

    test('big sample uses stats, overriding the self-report', () {
      // Claims beginner, but plays like a solid TAG over 500 hands.
      final level = CoachLevelResolver.resolve(
        pokerJourney: 'beginner',
        handsPlayed: 500,
        vpip: 20,
        pfr: 16,
        threeBet: 7,
        aggressionFactor: CoachLevelResolver.aggressionFactorFrom(20, 16),
      );
      expect(level, CoachLevel.advanced,
          reason: 'measured play beats the self-report');
    });

    test('exactly at the threshold trusts stats', () {
      final level = CoachLevelResolver.resolve(
        pokerJourney: 'fun',
        handsPlayed: CoachLevelResolver.minHandsForStats,
        vpip: 0,
        pfr: 0,
        threeBet: 0,
        aggressionFactor: 0,
      );
      // Zeroed stats → detector Unknown → beginner.
      expect(level, CoachLevel.beginner);
    });
  });

  group('aggressionFactorFrom', () {
    test('standard ratio', () {
      expect(CoachLevelResolver.aggressionFactorFrom(24, 18),
          closeTo(18 / 6, 0.001));
    });
    test('zero passive guard (vpip <= pfr)', () {
      expect(CoachLevelResolver.aggressionFactorFrom(18, 18), 0);
      expect(CoachLevelResolver.aggressionFactorFrom(10, 18), 0);
    });
  });

  group('CoachLevelId', () {
    test('id round-trips', () {
      for (final l in CoachLevel.values) {
        expect(CoachLevelId.fromId(l.id), l);
      }
    });
    test('unknown id falls back to beginner', () {
      expect(CoachLevelId.fromId('nope'), CoachLevel.beginner);
      expect(CoachLevelId.fromId(null), CoachLevel.beginner);
    });
  });
}
