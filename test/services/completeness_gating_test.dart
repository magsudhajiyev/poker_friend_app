import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/models/hand_completeness.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/services/csv_export_service.dart';
import 'package:poker_logger/services/leak_extractor.dart';
import 'package:poker_logger/services/local_storage_service.dart';
import 'package:poker_logger/services/pokerstars_export_service.dart';
import 'package:poker_logger/services/range_grid_service.dart';
import 'package:poker_logger/services/session_export_service.dart';

import '../fixtures/mock_hand_actions.dart';

typedef A = MockHandActions;

Map<String, dynamic> _fullHand({
  String? completeness,
  int number = 1,
  String heroAction = 'raise',
}) =>
    {
      if (completeness != null) 'completeness': completeness,
      'handNumber': number,
      'buttonPosition': 6,
      'playerCount': 6,
      'smallBlind': 1,
      'bigBlind': 2,
      'gameType': 'cash',
      'startTime': '2026-10-31T20:30:00.000Z',
      'heroSeatNumber': 3,
      'winnerId': 3,
      'potAmount': 12.0,
      'playerNames': {'1': 'A', '2': 'B', '3': 'Hero'},
      'ourHoleCards': {'card1': 'A♠', 'card2': 'K♥'},
      'actions': [
        A.smallBlind(1, 1),
        A.bigBlind(2, 2),
        A.action(player: 3, actionType: heroAction, amount: 6),
        A.fold(1),
        A.fold(2),
      ],
    };

void main() {
  group('LeakExtractor', () {
    test('only full hands are analysed', () {
      expect(LeakExtractor.extract(_fullHand()), isNotNull);
      expect(LeakExtractor.extract(_fullHand(completeness: 'full')), isNotNull);
      for (final c in ['fold_tick', 'preflop', 'flagged', 'reconstructed']) {
        expect(LeakExtractor.extract(_fullHand(completeness: c)), isNull,
            reason: c);
      }
    });
  });

  group('RangeGridService.buildEntry', () {
    RangeGridEntry? entry(HandCompleteness c, {HoleCards? cards}) =>
        RangeGridService.buildEntry(
          handKey: 's:1',
          sessionId: 's',
          userId: 'u',
          timestamp: DateTime(2026, 10, 31),
          gameType: 'cash',
          holeCards: cards,
          heroPositionName: 'CO',
          heroSeat: 3,
          actions: [
            {
              'player': 3,
              'action': 'fold',
              'street': 'preflop',
              'isCurrentUser': true,
              'playerStack': 200.0,
              'synthetic': true,
            }
          ],
          bigBlind: 2,
          potAmount: 0,
          winnerId: null,
          choppedWinners: null,
          completeness: c,
        );

    final cards = HoleCards(card1: '7♠', card2: '2♥');

    test('flagged is never indexed, even with cards', () {
      expect(entry(HandCompleteness.flagged, cards: cards), isNull);
    });

    test('tick / preflop / reconstructed / full need hole cards', () {
      for (final c in [
        HandCompleteness.foldTick,
        HandCompleteness.preflop,
        HandCompleteness.reconstructed,
        HandCompleteness.full,
      ]) {
        expect(entry(c), isNull, reason: '${c.wire} without cards');
        expect(entry(c, cards: cards), isNotNull, reason: '${c.wire} with cards');
      }
    });

    test('a fold tick lands in the fold cell', () {
      final e = entry(HandCompleteness.foldTick, cards: cards)!;
      expect(e.handClass, '72o');
      expect(e.primaryAction, 'fold');
    });
  });

  group('exports', () {
    final session = {
      'sessionName': 'S',
      'gameType': 'cash',
      'smallBlind': 1,
      'bigBlind': 2,
      'startTime': '2026-10-31T20:00:00.000',
      'endTime': '2026-10-31T22:00:00.000',
    };

    test('PokerStars exports full hands only', () {
      expect(PokerStarsExportService.exportHand(_fullHand(), session),
          isNotEmpty);
      for (final c in ['fold_tick', 'preflop', 'flagged', 'reconstructed']) {
        expect(
            PokerStarsExportService.exportHand(
                _fullHand(completeness: c), session),
            isEmpty,
            reason: c);
      }
      final text = PokerStarsExportService.exportSession(session, [
        _fullHand(number: 1),
        _fullHand(number: 2, completeness: 'reconstructed'),
        _fullHand(number: 3, completeness: 'fold_tick'),
      ]);
      expect(text.contains('#2'), isFalse);
      expect('PokerStars Hand'.allMatches(text).length, 1);
    });

    test('CSV rows exclude non-full hands', () {
      final svc = CSVExportService();
      final one = svc.exportHandToCsv(_fullHand());
      expect(one.split('\n').length, greaterThan(2));
      final tick = svc.exportHandToCsv(_fullHand(completeness: 'fold_tick'));
      expect(tick.trim().split('\n').length, 1, reason: 'header only');
      final all = svc.exportSessionToCsv(session, [
        _fullHand(number: 1),
        _fullHand(number: 2, completeness: 'flagged'),
      ]);
      expect(all.contains('Hero'), isTrue);
      expect(all.split('\n').where((l) => l.startsWith('2,')), isEmpty);
    });

    test('session totals: ticks via skippedHands, stubs ignored', () {
      final hands = [
        _fullHand(number: 1),
        _fullHand(number: 2, completeness: 'preflop'),
        _fullHand(number: 3, completeness: 'reconstructed'),
        _fullHand(number: 4, completeness: 'flagged'),
        _fullHand(number: 5, completeness: 'fold_tick', heroAction: 'fold'),
      ];
      final text = SessionExportService.generateStatsSummary(
          {...session, 'skippedHands': 1}, hands);
      // 3 counting hands (full, preflop, reconstructed) + 1 skipped tick.
      expect(text, contains('Hands Dealt: 4 (3 logged, 1 folded & skipped)'));
    });

    test('export with only non-full hands is rejected', () async {
      expect(
        () => SessionExportService.exportSession(
          userId: 'u',
          userEmail: 'e@x.y',
          session: session,
          hands: [_fullHand(completeness: 'flagged')],
        ),
        throwsException,
      );
    });
  });

  group('storage helpers', () {
    test('local session counter per level', () {
      expect(LocalStorageService.sessionCounterColumn(HandCompleteness.full),
          'totalHands');
      expect(
          LocalStorageService.sessionCounterColumn(HandCompleteness.preflop),
          'totalHands');
      expect(
          LocalStorageService.sessionCounterColumn(
              HandCompleteness.reconstructed),
          'totalHands');
      expect(
          LocalStorageService.sessionCounterColumn(HandCompleteness.foldTick),
          'skippedHands');
      expect(LocalStorageService.sessionCounterColumn(HandCompleteness.flagged),
          isNull);
    });

    test('v20 migration adds only the missing columns, additively', () {
      List<String> run(Set<Object?> have) =>
          LocalStorageService.missingHandsV20Statements(have);

      expect(run({'id'}).length, 3);
      for (final s in run({'id'})) {
        expect(s, startsWith('ALTER TABLE hands ADD COLUMN'));
      }
      expect(run({'id'}).join(' '), contains("completeness TEXT DEFAULT 'full'"));
      expect(run({'id'}).join(' '), contains('statsApplied INTEGER DEFAULT 1'));

      // Everything present: nothing to run (the reported crash).
      expect(run({'completeness', 'statsApplied', 'flagMeta'}), isEmpty);

      // Partial: only what is missing.
      final partial = run({'completeness'});
      expect(partial.length, 2);
      expect(partial.join(' '), isNot(contains('completeness')));
      expect(run({'completeness', 'statsApplied'}).single,
          'ALTER TABLE hands ADD COLUMN flagMeta TEXT');
    });

    test('addColumnStatement skips existing columns', () {
      expect(
          LocalStorageService.addColumnStatement(
              {'id', 'skippedHands'}, 'sessions', 'skippedHands', 'INTEGER DEFAULT 0'),
          isNull);
      expect(
          LocalStorageService.addColumnStatement(
              {'id'}, 'sessions', 'skippedHands', 'INTEGER DEFAULT 0'),
          'ALTER TABLE sessions ADD COLUMN skippedHands INTEGER DEFAULT 0');
    });

    test('onUpgrade has no raw ADD COLUMN left', () {
      final src = File('lib/services/local_storage_service.dart').readAsStringSync();
      final a = src.indexOf('onUpgrade: (db, oldVersion, newVersion)');
      final b = src.indexOf('onOpen: (db)');
      expect(src.substring(a, b).contains('ADD COLUMN'), isFalse);
    });

    test('schema version is 20', () {
      final src = File('lib/services/local_storage_service.dart').readAsStringSync();
      expect(src, contains('version: 20,'));
    });
  });

  group('allow-list (I31): who may call updateStatsAtomic', () {
    test('only the known call sites exist', () {
      final hits = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (l.contains('updateStatsAtomic(') && !l.contains('static Future')) {
            hits.add('${f.path}');
          }
        }
      }
      hits.sort();
      expect(hits, [
        // endSession (sessions/play-time deltas, no hand counters)
        'lib/services/firebase_service.dart',
        // dealer mode, per player
        'lib/services/firebase_service.dart',
        // OpponentStatsService
        'lib/services/firebase_service.dart',
        // applyHeroDelta (full / preflopOnly / foldTick / promotion)
        'lib/services/firebase_service.dart',
        // legacy Skip hand (flag OFF path)
        'lib/screens/poker_hand_screen.dart',
      ]..sort());
    });
  });
}
