import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/authored_tree.dart';
import 'package:poker_logger/services/notification_copy.dart';
import 'package:poker_logger/services/paid_nudge_copy.dart';
import 'package:poker_logger/services/spot_quiz_logic.dart';
import 'package:poker_logger/services/streak_saver_service.dart';

AuthoredTree _load(String id) => AuthoredTree.fromJson(
    json.decode(File('assets/authored/$id.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  group('spot choice', () {
    test('candidates are the 3 days BEFORE the fire day, never today', () {
      final c = SpotQuizLogic.candidateDays(DateTime(2026, 11, 5, 19));
      expect(c, [
        DateTime(2026, 11, 4),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 2),
      ]);
    });

    test('candidates cross a month boundary on calendar days', () {
      final c = SpotQuizLogic.candidateDays(DateTime(2026, 11, 2));
      expect(c.last, DateTime(2026, 10, 30));
    });

    test('pickStart is deterministic, in range, and varies by user/day', () {
      final a = SpotQuizLogic.pickStart('u1', '2026-11-05', 'day', 3);
      expect(SpotQuizLogic.pickStart('u1', '2026-11-05', 'day', 3), a);
      final seen = {
        for (var i = 0; i < 40; i++)
          SpotQuizLogic.pickStart('u$i', '2026-11-05', 'day', 3)
      };
      expect(seen, {0, 1, 2});
      expect(SpotQuizLogic.pickStart('u1', 'x', 'hand', 1), 0);
    });
  });

  group('fire time', () {
    final now = DateTime(2026, 11, 5, 12);

    test('never the current local day, even when the hour is far ahead', () {
      expect(SpotQuizLogic.fireTime(now, 19, []), DateTime(2026, 11, 6, 19));
      expect(SpotQuizLogic.fireTime(now, 23, []), DateTime(2026, 11, 6, 23));
      expect(SpotQuizLogic.fireTime(now, 12, []), DateTime(2026, 11, 6, 12));
    });

    test('a late-evening now still starts tomorrow', () {
      final late = DateTime(2026, 11, 5, 23, 50);
      expect(SpotQuizLogic.fireTime(late, 8, []), DateTime(2026, 11, 6, 8));
    });

    test('skips a day that already has an engagement push', () {
      final others = [DateTime(2026, 11, 6, 20)];
      expect(
          SpotQuizLogic.fireTime(now, 19, others), DateTime(2026, 11, 7, 19));
    });

    test('null when the 7-day offer cap is full', () {
      final others = [DateTime(2026, 11, 4, 9), DateTime(2026, 11, 7, 9)];
      expect(SpotQuizLogic.fireTime(now, 19, others), isNull);
    });
  });

  group('question facts from real trees', () {
    test('hero-first tree: action on you, real legal buttons', () {
      final tree = _load('lj-btn-ts9c4d-99');
      final spot = SpotQuizLogic.spotFor(tree)!;
      expect(spot.heroCards, '9♠ 9♥');
      expect(spot.heroPosition, tree.heroPosition);
      expect(spot.villainMove, isNull);
      expect(spot.buttons.length, inInclusiveRange(2, 3));
      for (final b in spot.buttons) {
        expect(tree.root.actions.contains(b.action), isTrue);
      }
    });

    test('every bundled tree yields a truthful spot or nothing', () {
      for (final id in [
        'lj-btn-ts9c4d-99',
        'btn-sb-qctd9d-kqs',
        'btn-bb-jd8h8d-tt',
        'btn-co-acjd4d-ajs',
      ]) {
        final tree = _load(id);
        final spot = SpotQuizLogic.spotFor(tree);
        expect(spot, isNotNull, reason: id);
        expect(spot!.buttons.toSet().length, spot.buttons.length);
        for (final b in spot.buttons) {
          expect(SpotQuizLogic.isStillLegal(tree, b), isTrue, reason: id);
        }
      }
    });

    test('villain-first tree names the villain move', () {
      final spot = SpotQuizLogic.spotFor(_load('btn-co-acjd4d-ajs'))!;
      expect(spot.villainMove, isNotNull);
    });

    test('more than 3 legal actions keeps the 3 the solver plays most', () {
      final tree = _load('lj-btn-ts9c4d-99');
      final node = tree.root;
      final j = node.toJson();
      // Give the node five actions with distinct hero-hand frequencies.
      j['actions'] = ['fold', 'check', 'call', 'raise', 'allin'];
      j['freq'] = {
        'fold': {tree.heroHandClass: 0.05},
        'check': {tree.heroHandClass: 0.40},
        'call': {tree.heroHandClass: 0.30},
        'raise': {tree.heroHandClass: 0.20},
        'allin': {tree.heroHandClass: 0.05},
      };
      final nodes = {...tree.nodes, node.id: TreeNode.fromJson(j)};
      final big = AuthoredTree.fromJson({
        ...tree.toJson(),
        'nodes': {for (final e in nodes.entries) e.key: e.value.toJson()}
      });
      final spot = SpotQuizLogic.spotFor(big)!;
      expect(spot.buttons.length, 3);
      expect(spot.buttons.contains(SpotQuizAction.check), isTrue);
      expect(spot.buttons.contains(SpotQuizAction.call), isTrue);
      expect(spot.buttons.contains(SpotQuizAction.fold), isFalse);
      expect(spot.buttons.contains(SpotQuizAction.allIn), isFalse);
    });

    test('a hand the solver never lists yields no quiz', () {
      final tree = _load('lj-btn-ts9c4d-99');
      final j = tree.toJson();
      j['heroHandClass'] = 'ZZ';
      expect(SpotQuizLogic.spotFor(AuthoredTree.fromJson(j)), isNull);
    });

    test('action ids map to tree actions (bet = raise)', () {
      expect(SpotQuizAction.fromId('bet')!.action, AuthoredAction.raise);
      expect(SpotQuizAction.fromId('allin')!.action, AuthoredAction.allin);
      expect(SpotQuizAction.fromId('nope'), isNull);
    });
  });

  group('payload + categories', () {
    test('button tap appends the action; body tap and junk do not', () {
      const p = 'engagement:spot_quiz:ev1';
      expect(SpotQuizLogic.payloadWithAction(p, 'call'), '$p:call');
      expect(SpotQuizLogic.payloadWithAction(p, null), p);
      expect(SpotQuizLogic.payloadWithAction(p, ''), p);
      expect(SpotQuizLogic.payloadWithAction(p, 'x'), p);
    });

    test('parsePayload reads the action and still accepts 2 segments', () {
      final a = StreakSaverService.parsePayload(SpotQuizLogic.payloadWithAction(
          'engagement:spot_quiz:ev1', 'raise'))!;
      expect(a.type, EngagementNotifType.spotQuiz);
      expect(a.eventId, 'ev1');
      expect(a.action, 'raise');
      final b = StreakSaverService.parsePayload('engagement:spot_quiz:ev1')!;
      expect(b.action, isNull);
      final old = StreakSaverService.parsePayload('engagement:missed_day:e9')!;
      expect(old.type, EngagementNotifType.missedDay);
      expect(old.action, isNull);
    });

    test('malformed 3rd segment or 4+ segments are rejected', () {
      for (final bad in [
        'engagement:spot_quiz:ev1:',
        'engagement:spot_quiz:ev1:call:x',
        'engagement:spot_quiz:ev1:maybe', // unknown button
        'engagement:missed_day:ev1:call', // only the quiz has buttons
      ]) {
        expect(StreakSaverService.parsePayload(bad), isNull, reason: bad);
      }
    });

    test('every 2-3 button set has a unique category (35 in total)', () {
      final ids =
          SpotQuizLogic.allCategories().map(SpotQuizLogic.categoryId).toSet();
      expect(ids.length, SpotQuizLogic.allCategories().length);
      expect(ids.length, 35);
      expect(
          ids.contains(SpotQuizLogic.categoryId([
            SpotQuizAction.fold,
            SpotQuizAction.call,
            SpotQuizAction.raise
          ])),
          isTrue);
    });

    test('target round-trips', () {
      final t = SpotQuizLogic.decodeTarget(
          SpotQuizLogic.encodeTarget('2026-11-04', 'btn-bb-x'))!;
      expect(t.dayKey, '2026-11-04');
      expect(t.treeId, 'btn-bb-x');
      expect(SpotQuizLogic.decodeTarget('garbage'), isNull);
      expect(SpotQuizLogic.decodeTarget(null), isNull);
    });

    test('spot_quiz is an offer type', () {
      expect(EngagementNotifType.spotQuiz.isOffer, isTrue);
      expect(EngagementNotifType.fromId('spot_quiz'),
          EngagementNotifType.spotQuiz);
    });
  });

  group('copy in every locale', () {
    final spots = [
      const SpotQuizSpot(
        treeId: 't',
        heroCards: 'J♠ 9♠',
        heroPosition: 'BB',
        villainPosition: 'BTN',
        villainMove: SpotQuizVillainMove.opened,
        buttons: [SpotQuizAction.fold, SpotQuizAction.call],
      ),
      for (final m in SpotQuizVillainMove.values)
        SpotQuizSpot(
          treeId: 't',
          heroCards: 'A♦ K♦',
          heroPosition: 'CO',
          villainPosition: 'SB',
          villainMove: m,
          buttons: const [SpotQuizAction.check, SpotQuizAction.bet],
        ),
      const SpotQuizSpot(
        treeId: 't',
        heroCards: '9♠ 9♥',
        heroPosition: 'LJ',
        villainPosition: 'BTN',
        villainMove: null,
        buttons: [SpotQuizAction.fold, SpotQuizAction.raise],
      ),
    ];

    for (final locale in AppLocalizations.supportedLocales) {
      test('${locale.languageCode}: real facts in, no placeholders out', () {
        final l10n = lookupAppLocalizations(Locale(locale.languageCode));
        for (final s in spots) {
          final (title, body) = PaidNudgeCopy.spotQuiz(l10n, s);
          expect(title, isNotEmpty);
          expect(body, contains(s.heroCards));
          expect(body, contains(s.heroPosition));
          if (s.villainMove != null) expect(body, contains(s.villainPosition));
          expect('$title$body', isNot(contains('{')));
        }
      });
    }

    test('English example matches the brief and reveals no answer', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final (t, b) = PaidNudgeCopy.spotQuiz(l10n, spots.first);
      expect(t, 'Your move');
      expect(b, 'J♠ 9♠ on BB. BTN opened. What do you do?');
    });
  });

  group('canonical buttons (iOS category)', () {
    test('order is the enum order whatever order the tree lists', () {
      final a = SpotQuizLogic.canonicalButtons(
          [SpotQuizAction.raise, SpotQuizAction.fold, SpotQuizAction.call]);
      final b = SpotQuizLogic.canonicalButtons(
          [SpotQuizAction.call, SpotQuizAction.raise, SpotQuizAction.fold]);
      expect(a, [SpotQuizAction.fold, SpotQuizAction.call, SpotQuizAction.raise]);
      expect(b, a);
    });

    test('a non-canonical set maps to a REGISTERED category id', () {
      final registered =
          SpotQuizLogic.allCategories().map(SpotQuizLogic.categoryId).toSet();
      final shuffled = [
        SpotQuizAction.allIn,
        SpotQuizAction.bet,
        SpotQuizAction.check
      ];
      expect(registered.contains(SpotQuizLogic.categoryId(shuffled)), isTrue);
      expect(SpotQuizLogic.categoryId(shuffled),
          SpotQuizLogic.categoryId(SpotQuizLogic.canonicalButtons(shuffled)));
    });

    test('duplicates collapse and more than 3 are capped', () {
      expect(
          SpotQuizLogic.canonicalButtons(
              [SpotQuizAction.fold, SpotQuizAction.fold, SpotQuizAction.call]),
          [SpotQuizAction.fold, SpotQuizAction.call]);
      expect(SpotQuizLogic.canonicalButtons(SpotQuizAction.values).length, 3);
    });
  });
}
