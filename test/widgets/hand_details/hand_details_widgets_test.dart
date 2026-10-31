import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/widgets/hand_details/hand_ai_analysis_card.dart';
import 'package:poker_logger/widgets/hand_details/hand_street_section.dart';
import 'package:poker_logger/widgets/hand_details/hand_summary_card.dart';
import 'package:poker_logger/widgets/hand_details/hand_tools_strip.dart';
import 'package:poker_logger/widgets/hand_details/hand_view_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _act(int p, String a, String st, num? amt, num stack,
        String pos, String name) =>
    {
      'player': p, 'action': a, 'street': st, 'amount': amt,
      'playerStack': stack, 'playerPosition': pos, 'playerName': name,
      'isCurrentUser': p == 1,
    };

Map<String, dynamic> _hand({bool allIn = false, bool cash = true}) => {
      'gameType': cash ? 'cash' : 'tournament',
      'smallBlind': 1, 'bigBlind': 2, 'buttonPosition': 3, 'playerCount': 6,
      'potAmount': 480, // int on purpose (cast regression)
      'preflopPot': 24, 'flopPot': 60, 'turnPot': 140, 'riverPot': 300,
      'winnerId': 1,
      'playerNames': {'1': 'Hero', '2': 'A very long opponent name indeed', '3': 'Bob'},
      'ourHoleCards': {'card1': 'A♠', 'card2': 'K♦'},
      'boardCards': {'flop': ['Q♥', 'J♣', '10♠'], 'turn': '2♦', 'river': '9♥'},
      'showdownData': {
        'playerCards': {'2': {'card1': 'Q♦', 'card2': 'Q♣'}}
      },
      'actions': [
        _act(2, 'raise', 'preflop', 6, 200, 'BTN', 'A very long opponent name indeed'),
        _act(1, 'call', 'preflop', 6, 200, 'SB', 'Hero'),
        _act(3, 'fold', 'preflop', null, 200, 'BB', 'Bob'),
        if (!allIn) ...[
          _act(1, 'check', 'flop', null, 194, 'SB', 'Hero'),
          _act(2, 'bet', 'flop', 10, 194, 'BTN', 'A very long opponent name indeed'),
          _act(1, 'call', 'flop', 10, 194, 'SB', 'Hero'),
          _act(1, 'check', 'turn', null, 184, 'SB', 'Hero'),
          _act(2, 'bet', 'turn', 40, 184, 'BTN', 'A very long opponent name indeed'),
          _act(1, 'call', 'turn', 40, 184, 'SB', 'Hero'),
          _act(1, 'check', 'river', null, 144, 'SB', 'Hero'),
          _act(2, 'all-in', 'river', 144, 144, 'BTN', 'A very long opponent name indeed'),
          _act(1, 'call', 'river', 144, 144, 'SB', 'Hero'),
        ] else
          _act(2, 'all-in', 'preflop', 200, 200, 'BTN', 'A very long opponent name indeed'),
      ],
    };

const _ai = {
  'aiAnalysis': {
    'reasoning':
        'You called preflop with a strong hand. The flop connected well.\nThe river shove is a polarised line and a very very long unbroken token ThisIsALongWordWithoutSpacesToTestWrappingBehaviour.',
    'learningPoint': 'Size your value bets so worse hands can call.',
  },
  'exploitativeTip': 'This opponent over-bluffs rivers; call lighter.',
  'streetBreakdown': {
    'preflop': {'grade': 'A', 'analysis': 'Fine call.'},
    'flop': {'grade': 'B', 'analysis': 'Check is ok.'},
    'turn': {'grade': 'C', 'analysis': 'Passive.'},
    'river': {'grade': 'F', 'analysis': 'Missed a raise.'},
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpAt(WidgetTester t, Size size, double scale, Widget child) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    ));
    await t.pump();
  }

  const sizes = [Size(320, 640), Size(390, 844)];
  const scales = [1.0, 1.5, 2.0];

  for (final size in sizes) {
    for (final scale in scales) {
      for (final showBB in [false, true]) {
        for (final allIn in [false, true]) {
          testWidgets(
              'hand widgets ${size.width.toInt()}x${size.height.toInt()} '
              'x$scale bb=$showBB allIn=$allIn',
              (t) async {
            final data = HandViewData.from(_hand(allIn: allIn),
                ourSeat: 1, showBB: showBB);
            await pumpAt(
              t, size, scale,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                HandSummaryCard(
                  data: data,
                  footer: HandToolsStrip(
                    showBB: showBB,
                    onShowBBChanged: (_) {},
                    amountLabel: r'$',
                    onExport: () {},
                    onShare: () {},
                  ),
                ),
                for (final b in data.streets)
                  HandStreetSection(block: b, data: data),
                const HandAiAnalysisCard(analysis: _ai),
              ]),
            );
            expect(t.takeException(), isNull);
            expect(find.text('Hero'), findsWidgets);
            expect(find.text('BB'), findsWidgets);
            expect(find.text(r'$'), findsOneWidget);
            expect(find.byIcon(Icons.download), findsOneWidget);
            expect(find.byIcon(Icons.ios_share), findsOneWidget);
            // Street pot: labelled caption + a value per street with a pot.
            expect(find.text('POT'), findsNWidgets(allIn ? 2 : 5));
            for (final sec in find.byType(HandStreetSection).evaluate()) {
              final pots = find.descendant(
                  of: find.byWidget(sec.widget), matching: find.text('POT'));
              if (pots.evaluate().isEmpty) continue;
              final secRight = t.getRect(find.byWidget(sec.widget)).right;
              final potRight = t.getRect(pots).right;
              expect((secRight - 12 - potRight).abs(), lessThan(4));
            }
            expect(allIn ? data.streets.length : data.streets.length,
                allIn ? 2 : 4);
          });
        }
      }
    }
  }

  testWidgets('tournament + sparse hand (no cards, no winner) renders',
      (t) async {
    final hand = _hand(cash: false)
      ..remove('ourHoleCards')
      ..remove('boardCards')
      ..remove('showdownData')
      ..remove('winnerId')
      ..remove('potAmount');
    final data = HandViewData.from(hand, showBB: false);
    await pumpAt(t, const Size(320, 640), 2.0, HandSummaryCard(data: data));
    expect(t.takeException(), isNull);
  });

  testWidgets('cards expose semantic labels', (t) async {
    final data = HandViewData.from(_hand(), ourSeat: 1, showBB: false);
    await pumpAt(t, const Size(390, 844), 1.0, HandSummaryCard(data: data));
    expect(find.bySemanticsLabel('Ace of spades'), findsOneWidget);
  });

  testWidgets('tools strip toggles display mode and fires callbacks',
      (t) async {
    var bb = false;
    var exported = 0, shared = 0;
    await pumpAt(
      t, const Size(320, 640), 2.0,
      StatefulBuilder(builder: (c, set) => HandToolsStrip(
            showBB: bb,
            onShowBBChanged: (v) => set(() => bb = v),
            amountLabel: r'$',
            onExport: () => exported++,
            onShare: () => shared++,
          )),
    );
    await t.tap(find.text('BB'));
    await t.pump();
    expect(bb, isTrue);
    await t.tap(find.text(r'$'));
    await t.pump();
    expect(bb, isFalse);
    await t.tap(find.byIcon(Icons.download));
    await t.tap(find.byIcon(Icons.ios_share));
    expect([exported, shared], [1, 1]);
    expect(t.takeException(), isNull);
  });
}
