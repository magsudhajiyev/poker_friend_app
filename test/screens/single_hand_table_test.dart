import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/screens/poker_hand_screen.dart';
import 'package:poker_logger/services/single_hand_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(WidgetTester t, SingleHandSetup s) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PokerHandScreen(
      smallBlind: s.smallBlind,
      bigBlind: s.bigBlind,
      numberOfPlayers: s.playerCount,
      gameType: s.gameType,
      hasBBante: s.hasBBante,
      singleHand: s,
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Iterable<String> _texts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((e) => e.data ?? e.textSpan?.toPlainText() ?? '');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cash 100 BB at 1/2 seats 200-chip stacks, villains by position',
      (t) async {
    await _open(t, SingleHandSetup(playerCount: 6, heroPosition: 'BTN'));
    final texts = _texts(t).toList();
    // Hero on the button keeps the full stack; blinds are posted from stacks.
    expect(texts.where((x) => x == '200').length, greaterThanOrEqualTo(4));
    expect(texts, containsAll(['SB', 'BB', 'UTG']));
    expect(texts, isNot(contains('P2')));
  });

  testWidgets('tournament 50 BB at 100/200 seats 10K stacks', (t) async {
    await _open(
        t,
        SingleHandSetup(
            gameType: GameType.tournament,
            smallBlind: 100,
            bigBlind: 200,
            stackBB: 50,
            playerCount: 6,
            heroPosition: 'CO'));
    final texts = _texts(t).toList();
    expect(texts.where((x) => x == '10K').length, greaterThanOrEqualTo(3));
    expect(texts, contains('9.9K')); // SB after posting 100
  });

  test('snapshot names: hero = nickname, villains = positions', () {
    final s = SingleHandSetup(playerCount: 6, heroPosition: 'CO')
      ..heroName = 'magsud';
    final seats = {for (final x in s.toSnapshot().seats) x.seat: x};
    expect(seats[1]!.name, 'magsud');
    expect(seats[1]!.position, 'CO');
    for (var i = 2; i <= 6; i++) {
      expect(seats[i]!.name, seats[i]!.position);
    }
    expect(seats[1]!.stack, 200);
    expect(SingleHandService.seatNames(s)[1], 'magsud');
    expect(SingleHandService.seatNames(s)[2], seats[2]!.position);
  });

  test('without a nickname the hero is saved by position', () {
    final s = SingleHandSetup(heroPosition: 'BTN');
    expect(SingleHandService.seatNames(s)[1], 'BTN');
  });

  testWidgets('rolled villain stacks show on the table', (t) async {
    final s = SingleHandSetup(
        playerCount: 6, heroPosition: 'BTN', stackSpread: StackSpread.similar)
      ..rollStacks(Random(5));
    await _open(t, s);
    final texts = _texts(t).toList();
    final rolled = s.villainStacks!.values.map((v) => v.toInt()).toSet();
    // At least one villain shows a rolled value that is not X (200).
    expect(rolled.any((v) => v != 200), isTrue);
    expect(texts.where((x) => x == '200').length, greaterThanOrEqualTo(1));
    for (final v in rolled.where((v) => v != 200 && v < 1000)) {
      // SB / BB seats show their stack minus the blind, others the full value.
      final shown = texts.contains('$v') ||
          texts.contains('${v - 1}') ||
          texts.contains('${v - 2}');
      expect(shown, isTrue, reason: 'stack $v not on the table');
    }
  });
}
