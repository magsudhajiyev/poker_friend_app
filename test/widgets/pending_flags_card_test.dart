import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/hand_flag_service.dart';
import 'package:poker_logger/widgets/easy_logging/pending_flags_card.dart';
import 'package:poker_logger/widgets/playing_card_face.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

FlaggedHandRef _ref(
  int n, {
  List<String> tags = const ['cooler'],
  Map<String, dynamic>? cards,
}) =>
    FlaggedHandRef(
      sessionId: 's1',
      handNumber: n,
      cloudId: 'c$n',
      flaggedAt: DateTime(2026, 10, 31, 21, 5),
      heroPositionName: 'BTN',
      heroStackBB: 98.4,
      tags: tags,
      heroCards: cards,
    );

void main() {
  testWidgets('renders nothing when there are no flags', (t) async {
    await t.pumpWidget(_host(PendingFlagsCard(
        flags: const [], onFinish: (_) {}, onDelete: (_) async {})));
    expect(find.text('Finish'), findsNothing);
  });

  testWidgets('shows count, rows, and Finish calls back', (t) async {
    FlaggedHandRef? finished;
    await t.pumpWidget(_host(PendingFlagsCard(
      flags: [_ref(1), _ref(2, tags: const ['bluff', 'review'])],
      onFinish: (r) => finished = r,
      onDelete: (_) async {},
    )));
    expect(find.text('2 flagged hands to finish'), findsOneWidget);
    expect(find.textContaining('BTN'), findsNWidgets(2));
    expect(find.textContaining('9:05'), findsNothing);
    expect(find.textContaining('PM'), findsNothing);
    expect(find.text('BTN  ·  98 BB'), findsNWidgets(2));
    expect(find.text('Bluff, Review'), findsOneWidget);
    await t.tap(find.text('Finish').first);
    expect(finished!.handNumber, 1);
  });

  testWidgets('Delete asks for confirmation first', (t) async {
    final deleted = <int>[];
    await t.pumpWidget(_host(PendingFlagsCard(
      flags: [_ref(1)],
      onFinish: (_) {},
      onDelete: (r) async => deleted.add(r.handNumber),
    )));
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(find.text('Delete flagged hand?'), findsOneWidget);
    expect(deleted, isEmpty);
    await t.tap(find.text('Delete').last);
    await t.pumpAndSettle();
    expect(deleted, [1]);
  });

  testWidgets('row shows the two hero cards when stored', (t) async {
    await t.pumpWidget(_host(PendingFlagsCard(
      flags: [_ref(1, cards: const {'card1': 'A♠', 'card2': 'K♥'})],
      onFinish: (_) {},
      onDelete: (_) async {},
    )));
    expect(find.byType(PlayingCardFace), findsNWidgets(2));
    expect(find.bySemanticsLabel('Ace of spades'), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('old stub without cards shows placeholders, no crash', (t) async {
    await t.pumpWidget(_host(PendingFlagsCard(
      flags: [
        _ref(1),
        _ref(2, cards: const {'card1': null, 'card2': null}),
        _ref(3, cards: const {'card1': 'Q♦', 'card2': ''}),
      ],
      onFinish: (_) {},
      onDelete: (_) async {},
    )));
    expect(t.takeException(), isNull);
    expect(find.text('?'), findsNWidgets(5));
    expect(find.byType(PlayingCardFace), findsOneWidget);
  });
}
