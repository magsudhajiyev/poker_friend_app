import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/hand_state_machine.dart';
import 'package:poker_logger/models/single_hand_group.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/models/tracked_session.dart';
import 'package:poker_logger/screens/logging_mode_selection_screen.dart';
import 'package:poker_logger/screens/single_hand_setup_screen.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/single_hand_service.dart';
import 'package:poker_logger/widgets/running_session_guard.dart';
import 'package:poker_logger/services/session_hand_info_pref.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_result_sheet.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_setup_sheet.dart'
    show SingleHandStart;
import 'package:poker_logger/widgets/tracked_session_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime(2026, 11, 25, 22);

SingleHandGroup _g(String id, String name, int hands) => SingleHandGroup(
      sessionId: id,
      name: name,
      gameType: GameType.cash,
      smallBlind: 1,
      bigBlind: 2,
      handCount: hands,
      lastHandAt: _t0,
    );

class _Backend
    implements SingleHandBackend, SingleHandMoveBackend, SingleHandRenameBackend {
  final List<SingleHandGroup> groups;
  final calls = <String>[];
  _Backend(this.groups);

  @override
  Future<List<SingleHandGroup>> loadGroups() async => groups;
  @override
  Future<int> handCount(String groupId) async => 0;
  @override
  Future<void> createGroup(
          {required String groupId,
          required String name,
          required SingleHandSetup setup}) async =>
      calls.add('create:$groupId:$name');
  @override
  Future<(String?, String?)> writeHand(
          {required String groupId,
          required int handNumber,
          required HandRecord hand,
          required SingleHandSetup setup,
          required Map<int, String> playerNames,
          Map<int, String>? playerIds}) async =>
      ('c', 'l');
  @override
  Future<void> touchGroup(String groupId, DateTime at) async {}
  @override
  Future<(String?, String?)> moveHand(
          {required String fromGroupId,
          required String toGroupId,
          required String handId,
          required int handNumber,
          required int newHandNumber}) async =>
      ('c', 'l');
  @override
  Future<void> renameGroup(String groupId, String name) async =>
      calls.add('rename:$groupId:$name');
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _bigScreen(WidgetTester t) {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  late _Backend b;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    b = _Backend([_g('old', 'Friday game', 4)]);
    SingleHandService.backend = b;
    SingleHandService.moveBackend = b;
    SingleHandService.renameBackend = b;
    SingleHandService.now = () => _t0;
    SingleHandService.newGroupId = () => 'new-id';
    SingleHandService.canAddHand = (n) => n < 50;
  });

  group('hand saved dialog (A)', () {
    Future<void> pumpDialog(WidgetTester t,
        {bool newGroup = true,
        bool inSession = false,
        bool nameNewGroup = true,
        bool infoHidden = false}) async {
      _bigScreen(t);
      await t.pumpWidget(_app(Scaffold(
        body: SingleHandSavedDialog(
          saved: SingleHandSaveResult(
            sessionId: 'new-id',
            handId: 'h',
            handNumber: 1,
            group: inSession
                ? _g('new-id', 'Casino', 1)
                : _g('new-id', kUnnamedGroupName, 1),
            newGroup: newGroup,
            inSession: inSession,
          ),
          nameNewGroup: nameNewGroup,
          infoHidden: infoHidden,
        ),
      )));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
    }

    bool enabled(WidgetTester t, String label) {
      final fade = t.widget<Opacity>(find
          .ancestor(of: find.text(label), matching: find.byType(Opacity))
          .first);
      return fade.opacity == 1.0;
    }

    testWidgets('simple: only Log another and Done, nothing else', (t) async {
      await pumpDialog(t, newGroup: false);
      expect(find.text('Log another'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('View hand'), findsNothing);
      expect(find.byIcon(Icons.star_border_rounded), findsNothing);
      expect(find.byKey(const ValueKey('saved-to-change')), findsNothing);
      expect(find.byType(TextField), findsNothing); // no notes
      expect(find.byKey(const ValueKey('session-info')), findsNothing);
      expect(enabled(t, 'Done'), isTrue);
    });

    testWidgets('a new group needs a name: both buttons wait for it',
        (t) async {
      await pumpDialog(t);
      expect(find.text('Name this group'), findsWidgets);
      expect(enabled(t, 'Done'), isFalse);
      expect(enabled(t, 'Log another'), isFalse);
      await t.enterText(find.byType(TextField).first, 'Casino night');
      await t.pump();
      expect(enabled(t, 'Done'), isTrue);
      expect(enabled(t, 'Log another'), isTrue);
      await t.enterText(find.byType(TextField).first, '   ');
      await t.pump();
      expect(enabled(t, 'Done'), isFalse);
    });

    testWidgets('earlier names are chips; one tap fills the field', (t) async {
      await pumpDialog(t);
      await t.tap(find.byKey(const ValueKey('group-name-chip-Friday game')));
      await t.pump();
      expect(enabled(t, 'Done'), isTrue);
    });

    testWidgets('Done stores the typed name on the group', (t) async {
      await pumpDialog(t);
      await t.enterText(find.byType(TextField).first, ' Casino night ');
      await t.pump();
      await t.tap(find.text('Done'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(b.calls, contains('rename:new-id:Casino night'));
    });

    testWidgets('v1 (no naming): a new group asks no name', (t) async {
      await pumpDialog(t, nameNewGroup: false);
      expect(find.text('Name this group'), findsNothing);
      expect(enabled(t, 'Done'), isTrue);
    });

    testWidgets('in a session: info line + checkbox, no group name',
        (t) async {
      await pumpDialog(t, inSession: true);
      expect(find.text('Name this group'), findsNothing);
      expect(find.text('AI analysis and sharing unlock when the session ends.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('dont-show-again')), findsOneWidget);
      expect(enabled(t, 'Done'), isTrue);
    });

    testWidgets('Don\'t show again stores the pref; the line then stays away',
        (t) async {
      await pumpDialog(t, inSession: true);
      await t.tap(find.byKey(const ValueKey('dont-show-again')));
      await t.pump();
      await t.tap(find.text('Done'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(await SessionHandInfoPref.hidden(), isTrue);
      await pumpDialog(t, inSession: true, infoHidden: true);
      expect(find.byKey(const ValueKey('session-info')), findsNothing);
    });

    testWidgets('a hand in a normal group shows no session info', (t) async {
      await pumpDialog(t, newGroup: false);
      expect(find.byKey(const ValueKey('session-info')), findsNothing);
    });
  });

  group('setup screen: Saving to <session> (D23)', () {
    SingleHandStart? result;
    const session =
        SingleHandSessionTarget('sess', 'Casino', GameType.cash);

    Future<void> open(WidgetTester t, SingleHandSetup setup,
        {SingleHandSessionTarget? target = session}) async {
      _bigScreen(t);
      result = null;
      await t.pumpWidget(_app(Builder(
        builder: (c) => TextButton(
          onPressed: () async => result = await SingleHandSetupScreen.show(c,
              setup: setup, session: target),
          child: const Text('open'),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('shows one line; Start saves into the session by default',
        (t) async {
      await open(t, SingleHandSetup());
      expect(find.text('Saving to Casino'), findsOneWidget);
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();
      expect(result?.session?.id, 'sess');
      expect(result?.group, isNull);
    });

    testWidgets('no line without a running session', (t) async {
      await open(t, SingleHandSetup(), target: null);
      expect(find.textContaining('Saving to'), findsNothing);
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();
      expect(result?.session, isNull);
    });

    testWidgets('the session fixes the game type', (t) async {
      await open(
          t,
          SingleHandSetup(
              gameType: GameType.tournament,
              smallBlind: 100,
              bigBlind: 200),
          target: const SingleHandSessionTarget(
              'sess', 'Casino', GameType.cash));
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();
      expect(result!.setup.gameType, GameType.cash);
    });

    testWidgets('picking a hand group instead leaves the session',
        (t) async {
      await open(t, SingleHandSetup());
      await t.tap(find.byKey(const ValueKey('saving-to')));
      await t.pumpAndSettle();
      expect(find.text('Friday game'), findsOneWidget);
      await t.tap(find.text('Friday game'));
      await t.pumpAndSettle();
      expect(find.text('Saving to a hand group'), findsOneWidget);
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();
      expect(result?.session, isNull);
      expect(result?.group?.sessionId, 'old');
    });

    testWidgets('a new hand group, and back to the session', (t) async {
      await open(t, SingleHandSetup());
      await t.tap(find.byKey(const ValueKey('saving-to')));
      await t.pumpAndSettle();
      await t.tap(find.text('New hand group'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('saving-to')));
      await t.pumpAndSettle();
      await t.tap(find.text('Casino'));
      await t.pumpAndSettle();
      expect(find.text('Saving to Casino'), findsOneWidget);
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();
      expect(result?.session?.id, 'sess');
    });
  });

  group('+ card and badges', () {
    test('Track a session card is hidden during the tour or with the flag off',
        () {
      expect(
          LoggingModeSelectionScreen.trackedSessionCardVisible(
              flagOn: true, tourActive: false),
          isTrue);
      expect(
          LoggingModeSelectionScreen.trackedSessionCardVisible(
              flagOn: true, tourActive: true),
          isFalse);
      expect(
          LoggingModeSelectionScreen.trackedSessionCardVisible(
              flagOn: false, tourActive: false),
          isFalse);
    });

    testWidgets('history badge shows the hand count', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: TrackedHandsBadge(12))));
      expect(find.text('12 hands'), findsOneWidget);
      await t.pumpWidget(_app(const Scaffold(body: TrackedHandsBadge(1))));
      expect(find.text('1 hand'), findsOneWidget);
    });
  });

  group('discard warning (D24)', () {
    testWidgets('names the number of logged hands', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      final l10n = AppLocalizations.of(ctx);
      expect(TrackedDiscardDialog.message(l10n, 7),
          contains('This also deletes 7 logged hands.'));
      expect(TrackedDiscardDialog.message(l10n, 1),
          contains('This also deletes 1 logged hand.'));
      expect(TrackedDiscardDialog.message(l10n, 0), isNot(contains('deletes')));
    });

    testWidgets('the dialog shows the warning and resolves on tap', (t) async {
      bool? answer;
      await t.pumpWidget(_app(Builder(
        builder: (c) => TextButton(
          onPressed: () async =>
              answer = await TrackedDiscardDialog.confirm(c, 3),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.textContaining('This also deletes 3 logged hands.'),
          findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(answer, isTrue);
    });
  });

  group('one running session: blocked, not ended (C)', () {
    final running = LiveSessionRecord(
        sessionId: 'r', name: 'Casino', gameType: 'cash', startTime: _t0);

    Future<bool?> ask(WidgetTester t, {String? tap}) async {
      bool? result;
      await t.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () async =>
                result = await RunningSessionGuard.ensureFree(c),
            child: const Text('go'),
          ),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      if (tap != null) {
        await t.tap(find.text(tap));
        await t.pumpAndSettle();
      }
      return result;
    }

    testWidgets('nothing running: no question', (t) async {
      RunningSessionGuard.current = () async => null;
      expect(await ask(t), isTrue);
      expect(find.text('A session is running'), findsNothing);
    });

    testWidgets('running: info dialog, no end-and-continue; Go to session '
        'opens it and still blocks', (t) async {
      final opened = <String>[];
      RunningSessionGuard.current = () async => running;
      RunningSessionGuard.goTo = (nav, r) async => opened.add(r.sessionId);
      bool? result;
      await t.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () async =>
                result = await RunningSessionGuard.ensureFree(c),
            child: const Text('go'),
          ),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(
          find.text(
              'Casino is still running. End it before you start a new session.'),
          findsOneWidget);
      expect(find.text('End and continue'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      await t.tap(find.text('Go to session'));
      await t.pumpAndSettle();
      expect(result, isFalse);
      expect(opened, ['r']);
    });

    testWidgets('running: Cancel blocks and opens nothing', (t) async {
      final opened = <String>[];
      RunningSessionGuard.current = () async => running;
      RunningSessionGuard.goTo = (nav, r) async => opened.add(r.sessionId);
      expect(await ask(t, tap: 'Cancel'), isFalse);
      expect(opened, isEmpty);
    });
  });
}
