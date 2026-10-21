import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/notification_copy.dart';

/// Engagement notification copy: every (type × voice) renders, placeholders
/// always resolve, re-engage is never coach-voiced, variants rotate.
void main() {
  const coaches = ['grinder', 'professor', 'nova'];

  group('catalog completeness', () {
    test('every type renders for every coach and neutral, all variants', () {
      for (final type in EngagementNotifType.values) {
        for (final voice in [...coaches, null, 'retired_coach']) {
          final n = NotificationCopy.variantCount(type, voice);
          expect(n, greaterThanOrEqualTo(1), reason: '${type.id}/$voice');
          for (var v = 0; v < n; v++) {
            final c = NotificationCopy.copyFor(type, voice, v,
                streak: 12, rank: 4);
            expect(c.title, isNotEmpty);
            expect(c.body, isNotEmpty);
          }
        }
      }
    });

    test('no unresolved placeholders, with or without values', () {
      for (final type in EngagementNotifType.values) {
        for (final voice in [...coaches, null]) {
          for (var v = 0; v < 4; v++) {
            for (final args in [
              (streak: 12, rank: 4),
              (streak: null, rank: null),
            ]) {
              final c = NotificationCopy.copyFor(type, voice, v,
                  streak: args.streak, rank: args.rank);
              expect('${c.title} ${c.body}'.contains('{'), isFalse,
                  reason: '${type.id}/$voice v$v left a placeholder: '
                      '"${c.title} / ${c.body}"');
            }
          }
        }
      }
    });
  });

  group('voice rules', () {
    test('re-engage is ALWAYS the neutral voice — no coach sass for lapsed',
        () {
      for (final coach in coaches) {
        final withCoach =
            NotificationCopy.copyFor(EngagementNotifType.reEngage, coach, 0);
        final neutral =
            NotificationCopy.copyFor(EngagementNotifType.reEngage, null, 0);
        expect(withCoach.title, neutral.title);
        expect(withCoach.body, neutral.body);
      }
    });

    test('unknown/retired coach falls back to neutral', () {
      final unknown = NotificationCopy.copyFor(
          EngagementNotifType.dcTodayReady, 'rocket', 0);
      final neutral = NotificationCopy.copyFor(
          EngagementNotifType.dcTodayReady, null, 0);
      expect(unknown.title, neutral.title);
    });

    test('coach voices actually differ from each other', () {
      final duke = NotificationCopy.copyFor(
          EngagementNotifType.dcStreakRisk, 'grinder', 0, streak: 5);
      final nova = NotificationCopy.copyFor(
          EngagementNotifType.dcStreakRisk, 'nova', 0, streak: 5);
      expect(duke.body, isNot(nova.body));
    });
  });

  group('placeholder interpolation', () {
    test('streak phrase carries the number', () {
      final c = NotificationCopy.copyFor(
          EngagementNotifType.dcStreakRisk, 'grinder', 0,
          streak: 12);
      expect(c.body, contains('12-day streak'));
    });

    test('rank phrase carries the rank', () {
      final c = NotificationCopy.copyFor(
          EngagementNotifType.lbOvertaken, 'professor', 0,
          rank: 4);
      expect(c.body, contains('#4'));
    });

    test('missing values degrade to generic wording, still readable', () {
      final c = NotificationCopy.copyFor(
          EngagementNotifType.dcStreakRisk, 'nova', 0);
      expect(c.body.toLowerCase(), contains('streak'));
      expect(c.body, isNot(contains('-day')));
    });
  });

  group('variant rotation', () {
    test('variant index rotates modulo the pool; same index is stable', () {
      final n = NotificationCopy.variantCount(
          EngagementNotifType.dcTodayReady, 'nova');
      expect(n, greaterThanOrEqualTo(2));
      final a = NotificationCopy.copyFor(
          EngagementNotifType.dcTodayReady, 'nova', 0);
      final b = NotificationCopy.copyFor(
          EngagementNotifType.dcTodayReady, 'nova', 1);
      final aWrap = NotificationCopy.copyFor(
          EngagementNotifType.dcTodayReady, 'nova', n);
      expect(a.body, isNot(b.body), reason: 'adjacent variants differ');
      expect(aWrap.body, a.body, reason: 'wraps around the pool');
    });
  });

  group('wire ids', () {
    test('round-trip through fromId; priority order preserved', () {
      for (final t in EngagementNotifType.values) {
        expect(EngagementNotifType.fromId(t.id), t);
      }
      expect(EngagementNotifType.fromId('nonsense'), isNull);
      expect(EngagementNotifType.values.first,
          EngagementNotifType.dcStreakRisk,
          reason: 'streak-saver is highest priority');
    });
  });
}
