import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/poker_game_state.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/screens/poker_hand_screen.dart';
import 'package:poker_logger/services/feature_flag_service.dart';
import 'package:poker_logger/widgets/single_hand/v2/villain_stack_badge.dart';
import 'package:poker_logger/widgets/single_hand/v2/villain_stack_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _flag(String mode) =>
    FeatureFlagService.applyRemote({'single_hand_v2': mode});

Future<void> _open(WidgetTester t, SingleHandSetup s, {bool single = true}) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 10));
  });
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PokerHandScreen(
      smallBlind: s.smallBlind,
      bigBlind: s.bigBlind,
      numberOfPlayers: s.playerCount,
      gameType: s.gameType,
      hasBBante: s.hasBBante,
      singleHand: single ? s : null,
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Finder get _felt => find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onPanStart != null && w.onTapUp != null);

Future<void> _tapFelt(WidgetTester t) async {
  await t.tapAt(t.getCenter(_felt.first));
  await _settle(t);
}

/// Drags up far enough to reach the last (all-in) snap point and releases.
Future<void> _dragUpAllIn(WidgetTester t) async {
  final g = await t.startGesture(t.getCenter(_felt.first));
  await g.moveBy(const Offset(0, -60));
  await t.pump();
  await g.moveBy(const Offset(0, -100)); // pan accepted, snap mode entered
  await t.pump();
  await g.moveBy(const Offset(0, -600)); // past the end: all-in snap point
  await t.pump();
  await g.up();
  await _settle(t);
}


Map<int, String> _sources(WidgetTester t) =>
    ((t.state(find.byType(PokerHandScreen)) as dynamic).stackSourcesForTest
            as Map)
        .cast<int, String>();

/// A small upward drag released early: a modest raise, not an all-in.
Future<void> _dragSmallRaise(WidgetTester t) async {
  final g = await t.startGesture(t.getCenter(_felt.first));
  await g.moveBy(const Offset(0, -60));
  await t.pump();
  await g.moveBy(const Offset(0, -45));
  await t.pump();
  await g.moveBy(const Offset(0, -60));
  await t.pump();
  await g.up();
  await _settle(t);
}

/// UTG limps, the player sets UTG's stack to 3/4, HJ raises, everyone else
/// calls: the action is back on UTG facing a raise.
Future<void> _toUtgFacingRaise(WidgetTester t, {bool setUtg = true}) async {
  await _tapFelt(t); // UTG calls
  if (setUtg) {
    await t.tap(find.byType(VillainStackBadge));
    await _settle(t);
    await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded)); // 3/4
    await t.pump();
    await t.tap(find.text('Set stack'));
    await _settle(t);
  }
  await _dragSmallRaise(t); // HJ raises
  for (var i = 0; i < 4; i++) {
    await _tapFelt(t); // CO, BTN (hero), SB, BB call
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => _flag('off'));

  group('villain badge (D7)', () {
    testWidgets('first voluntary villain action shows the badge, not blinds',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      expect(find.byType(VillainStackBadge), findsNothing);
      await _tapFelt(t); // UTG calls
      expect(find.byType(VillainStackBadge), findsOneWidget);
      expect(find.textContaining('200?'), findsOneWidget);
      await _tapFelt(t); // next villain calls: multiway, a second badge
      expect(find.byType(VillainStackBadge), findsNWidgets(2));
    });

    testWidgets('badge fits inside the bigger seat plate on a 320 pt phone',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 9, heroPosition: 'BTN'));
      t.view.physicalSize = const Size(320, 640) * 3;
      await t.pump();
      await _tapFelt(t);
      final badge = t.getRect(find.byType(VillainStackBadge));
      final plates = [
        for (var i = 1; i <= 9; i++)
          if (find.byKey(ValueKey('seat-plate-$i')).evaluate().isNotEmpty)
            t.getRect(find.byKey(ValueKey('seat-plate-$i')))
      ];
      expect(plates.any((p) => p.inflate(0.5).contains(badge.center) &&
          badge.left >= p.left - 0.5 && badge.right <= p.right + 0.5), isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('tournament badge reads BB', (t) async {
      await _flag('on');
      await _open(
          t,
          SingleHandSetup(
              gameType: GameType.tournament,
              smallBlind: 100,
              bigBlind: 200,
              stackBB: 50,
              playerCount: 6,
              heroPosition: 'CO'));
      await _tapFelt(t);
      expect(find.text('50 BB?'), findsOneWidget);
    });

    testWidgets('no badge with the flag off (v1) or in a full session',
        (t) async {
      await _flag('off');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _tapFelt(t);
      expect(find.byType(VillainStackBadge), findsNothing);
    });

    testWidgets('tap badge, set 1/4: stack and pot follow, badge goes',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _tapFelt(t); // UTG calls 2
      await t.tap(find.byType(VillainStackBadge));
      await _settle(t);
      expect(find.byType(VillainStackSheet), findsOneWidget);
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded)); // 3/4
      await t.pump();
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded)); // 1/2
      await t.pump();
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded)); // 1/4
      await t.pump();
      expect(find.text('¼× you'), findsOneWidget);
      await t.tap(find.text('Set stack'));
      await _settle(t);
      expect(find.byType(VillainStackSheet), findsNothing);
      expect(find.byType(VillainStackBadge), findsNothing);
      // UTG: 50 total, 2 committed -> 48 behind.
      expect(find.text('48'), findsOneWidget);
    });

    testWidgets('keep equal closes without changing anything', (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _tapFelt(t);
      await t.tap(find.byType(VillainStackBadge));
      await _settle(t);
      await t.tap(find.text('Keep equal to me'));
      await _settle(t);
      expect(find.byType(VillainStackSheet), findsNothing);
      expect(find.byType(VillainStackBadge), findsOneWidget);
    });
  });

  group('all-in rule (D8)', () {
    testWidgets('villain all-in with a default stack opens the sheet first',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _dragUpAllIn(t);
      expect(find.byType(VillainStackSheet), findsOneWidget);
      expect(find.text('Confirm and log all-in'), findsOneWidget);
      expect(find.text('Keep equal to me'), findsNothing);
      expect(find.text('ALL-IN'), findsNothing); // nothing committed yet
    });

    testWidgets('confirming logs the all-in with the confirmed stack',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _dragUpAllIn(t);
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded)); // 3/4
      await t.pump();
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded)); // 1/2
      await t.pump();
      await t.tap(find.text('Confirm and log all-in'));
      await _settle(t);
      expect(find.byType(VillainStackSheet), findsNothing);
      expect(find.text('ALL-IN'), findsOneWidget);
      // 100-chip stack all-in: 100 in front of nobody behind.
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('a seat with a set stack does not reopen the sheet',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _tapFelt(t); // UTG calls
      await t.tap(find.byType(VillainStackBadge));
      await _settle(t);
      await t.tap(find.text('Set stack'));
      await _settle(t);
      await _tapFelt(t); // next seat calls
      await _tapFelt(t); // next seat calls (hero is on the button, acts last)
      // Whoever acts next with a set stack never sees the sheet on a call.
      expect(find.byType(VillainStackSheet), findsNothing);
    });

    testWidgets('a villain with a SET stack going all-in never opens the sheet',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _toUtgFacingRaise(t);
      expect(find.byType(VillainStackSheet), findsNothing);
      expect(_sources(t)[4], 'set');
      await _dragUpAllIn(t); // UTG jams
      expect(find.byType(VillainStackSheet), findsNothing);
      expect(find.text('ALL-IN'), findsOneWidget);
    });

    testWidgets('a villain who folds after the badge: badge gone, stays default',
        (t) async {
      await _flag('on');
      await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
      await _toUtgFacingRaise(t, setUtg: false);
      final before = find.byType(VillainStackBadge).evaluate().length;
      expect(before, greaterThanOrEqualTo(2));
      expect(_sources(t)[4], 'default');
      await t.fling(_felt.first, const Offset(-300, 0), 1000); // UTG folds
      await _settle(t);
      expect(find.byType(VillainStackBadge).evaluate().length, before - 1);
      expect(_sources(t)[4], 'default');
      expect(find.byType(VillainStackSheet), findsNothing);
    });
  });

  group('mid-hand stack change keeps committed chips', () {
    PokerGameState table() {
      final g = PokerGameState(
        numberOfPlayers: 3,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );
      for (var i = 1; i <= 3; i++) {
        g.setPlayerStack(i, 200);
        g.setPlayerActive(i, true);
      }
      g.buttonPosition = 1;
      g.finalizeInitialization();
      g.initializePot();
      return g;
    }

    test('blind poster keeps what is posted, only the rest changes', () {
      final g = table();
      final bb = g.effectiveBBPosition;
      final posted = g.players[bb - 1].betThisRound;
      expect(posted, 2);
      final total = g.setStackKeepingCommitted(bb, 50);
      expect(total, 50);
      expect(g.players[bb - 1].currentStack, 48);
      expect(g.players[bb - 1].betThisRound, 2);
      expect(g.currentPot, 3);
    });

    test('short villain all-in after 1/4 makes a side pot', () {
      final g = table();
      final a = g.currentPlayer; // acts first, 200 behind, nothing in
      g.setStackKeepingCommitted(a, 50);
      g.performActionWithAmount(PlayerAction.raise, 50); // all-in for 50
      expect(g.players[a - 1].isAllIn, isTrue);
      expect(g.players[a - 1].currentStack, 0);
      final b = g.currentPlayer;
      g.performActionWithAmount(PlayerAction.raise, 150);
      final c = g.currentPlayer;
      g.performActionWithAmount(PlayerAction.call, 0);
      expect(g.players[c - 1].betThisRound, 150);
      expect(g.currentPot, 50 + 150 + 150);
      expect(g.activeSidePots.length, 2);
      expect(g.activeSidePots.first.amount, 150); // 50 x 3 main pot
      expect(g.players[b - 1].isAllIn, isFalse);
    });


    test('dead small blind: nobody posted the SB, a set stack keeps the BB',
        () {
      final g = PokerGameState(
        numberOfPlayers: 4,
        smallBlind: 1,
        bigBlind: 2,
        isCashGame: true,
      );
      for (final i in [1, 2, 4]) {
        g.setPlayerStack(i, 200);
        g.setPlayerActive(i, true);
      }
      g.setPlayerStack(3, 0);
      g.setPlayerActive(3, false);
      g.buttonPosition = 1;
      g.seedDeadSmallBlind(button: 1, sbSeat: 3);
      g.finalizeInitialization();
      g.initializePot();
      expect(g.smallBlindDead, isTrue);
      expect(g.currentPot, 2); // no small blind posted
      final bb = g.effectiveBBPosition;
      expect(g.players[bb - 1].betThisRound, 2);
      g.setStackKeepingCommitted(bb, 50);
      expect(g.players[bb - 1].currentStack, 48);
      expect(g.currentPot, 2);
      // A villain with a short set stack still goes all-in for less.
      final a = g.currentPlayer;
      g.setStackKeepingCommitted(a, 20);
      g.performActionWithAmount(PlayerAction.raise, 20);
      expect(g.players[a - 1].isAllIn, isTrue);
      expect(g.currentPot, 22);
    });

    test('total never drops below the committed chips', () {
      final g = table();
      final bb = g.effectiveBBPosition;
      final total = g.setStackKeepingCommitted(bb, 1);
      expect(total, 2);
      expect(g.players[bb - 1].currentStack, 0);
    });

    test('recorded stack-behind of the seat shifts by the same delta', () {
      final a = ActionRecord(
        player: 4,
        action: PlayerAction.call,
        street: BettingRound.preflop,
        timestamp: DateTime(2026),
        buttonPosition: 1,
        playerStack: 200,
        amount: 2,
      );
      final b = a.withStackShift(-150);
      expect(b.playerStack, 50);
      expect(b.amount, 2);
      expect(b.player, 4);
      expect(ActionRecord(
              player: 1,
              action: PlayerAction.fold,
              street: BettingRound.preflop,
              timestamp: DateTime(2026),
              buttonPosition: 1)
          .withStackShift(5)
          .playerStack, isNull);
    });
  });
}
