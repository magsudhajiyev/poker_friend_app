import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/models/game_types.dart';
import 'package:poker_logger/models/single_hand_setup.dart';
import 'package:poker_logger/models/tracked_session.dart';
import 'package:poker_logger/screens/single_hand_setup_screen.dart';
import 'package:poker_logger/screens/tracked_session_hub.dart';
import 'package:poker_logger/services/live_session_logic.dart';
import 'package:poker_logger/services/live_session_notification_service.dart';
import 'package:poker_logger/services/session_navigation.dart';
import 'package:poker_logger/services/tracked_session_service.dart';
import 'package:poker_logger/widgets/live_session_bar.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_flow.dart';
import 'package:poker_logger/widgets/single_hand/single_hand_setup_sheet.dart'
    show SingleHandStart;
import 'package:shared_preferences/shared_preferences.dart';

class _Counter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushes++;
  }
}

class _Slow implements TrackedSessionBackend {
  final doc = {
    'sessionType': 'tracked',
    'sessionName': 'Casino',
    'gameType': 'cash',
    'startTime': DateTime.now().toIso8601String(),
    'buyInAmount': 100.0,
    'totalBuyIn': 100.0,
    'currentStack': 100.0,
  };
  int loads = 0;
  @override
  Future<void> create(TrackedSession s) async {}
  @override
  Future<Map<String, dynamic>?> load(String id) async {
    loads++;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return doc;
  }

  @override
  Future<int> handCount(String id) async => 0;
  @override
  Future<void> recordResult(String id,
      {double? currentStack,
      int? finishedPlace,
      int? fieldSize,
      double? prizeWon}) async {}
  @override
  Future<void> end(String id, DateTime at) async {}
  @override
  Future<void> discard(String id) async {}
}

Widget _app(Widget home, {List<NavigatorObserver> observers = const []}) =>
    MaterialApp(
      navigatorObservers: observers,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionNavigation.reset();
    LiveSessionNotificationService.running.value = null;
  });

  testWidgets('openOnce: 5 rapid calls push exactly one route', (t) async {
    final obs = _Counter();
    late NavigatorState nav;
    await t.pumpWidget(_app(
      Builder(builder: (c) {
        nav = Navigator.of(c);
        return TextButton(
          onPressed: () => SessionNavigation.openOnce<void>(
              nav,
              'hub:x',
              () => MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('hub')))),
          child: const Text('open'),
        );
      }),
      observers: [obs],
    ));
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('open'), warnIfMissed: false);
    }
    await t.pumpAndSettle();
    expect(obs.pushes, 1);
    nav.pop();
    await t.pumpAndSettle();
    expect(find.text('hub'), findsNothing); // one Back returns home
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a hub already in the stack: pop back to it, never push again',
      (t) async {
    final obs = _Counter();
    late NavigatorState nav;
    await t.pumpWidget(_app(
      Builder(builder: (c) {
        nav = Navigator.of(c);
        return const Text('home');
      }),
      observers: [obs],
    ));
    SessionNavigation.openOnce<void>(nav, 'hub:x',
        () => MaterialPageRoute<void>(builder: (_) => const Text('hub')));
    await t.pumpAndSettle();
    // Something else is pushed on top of the hub.
    nav.push(MaterialPageRoute<void>(builder: (_) => const Text('above')));
    await t.pumpAndSettle();
    expect(find.text('above'), findsOneWidget);
    SessionNavigation.openOnce<void>(nav, 'hub:x',
        () => MaterialPageRoute<void>(builder: (_) => const Text('dup')));
    await t.pumpAndSettle();
    expect(find.text('above'), findsNothing);
    expect(find.text('hub'), findsOneWidget);
    expect(find.text('dup'), findsNothing);
    expect(obs.pushes, 2); // hub + above, no third
  });

  testWidgets('after the hub closes it can be opened again', (t) async {
    late NavigatorState nav;
    await t.pumpWidget(_app(Builder(builder: (c) {
      nav = Navigator.of(c);
      return const Text('home');
    })));
    Route<void> make() =>
        MaterialPageRoute<void>(builder: (_) => const Text('hub'));
    SessionNavigation.openOnce<void>(nav, 'k', make);
    await t.pumpAndSettle();
    nav.pop();
    await t.pumpAndSettle();
    expect(SessionNavigation.isOpen('k'), isFalse);
    SessionNavigation.openOnce<void>(nav, 'k', make);
    await t.pumpAndSettle();
    expect(find.text('hub'), findsOneWidget);
  });

  testWidgets(
      'Home bar: 5 rapid taps on a slow load -> one hub, loading state at '
      'once, one Back returns', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final backend = _Slow();
    TrackedSessionService.backend = backend;
    TrackedSessionHub.registerHooks();
    LiveSessionNotificationService.running.value = LiveSessionRecord(
        sessionId: 's1',
        name: 'Casino',
        gameType: 'cash',
        startTime: DateTime.now().subtract(const Duration(minutes: 5)));
    final obs = _Counter();
    await t.pumpWidget(_app(const Scaffold(body: LiveSessionBar()),
        observers: [obs]));
    await t.pump();
    for (var i = 0; i < 5; i++) {
      await t.tap(find.textContaining('Casino'), warnIfMissed: false);
    }
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    // The screen is up at once, before the doc arrived.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(obs.pushes, 1);
    expect(backend.loads, 1);
    expect(find.text('Log a Hand'), findsOneWidget);
    Navigator.of(t.element(find.text('Log a Hand'))).pop();
    await t.pumpAndSettle();
    expect(find.byType(LiveSessionBar), findsOneWidget);
    expect(find.text('Log a Hand'), findsNothing);
  });

  group('running FULL session: resume table, never mix hands (D)', () {
    const full =
        SingleHandSessionTarget('f', 'Home game', GameType.cash, isFull: true);
    const tracked = SingleHandSessionTarget('t', 'Casino', GameType.cash);

    test('target resolution', () {
      // Tracked wins and is saved into.
      var r = SingleHandFlow.resolveTarget(
          tracked: tracked, full: null, fullTableOpen: false);
      expect(r.target, tracked);
      // Full + table still open -> default "resume table".
      r = SingleHandFlow.resolveTarget(
          tracked: null, full: full, fullTableOpen: true);
      expect(r.target, full);
      expect(r.resumeUnavailable, isFalse);
      // Full after a restart -> hand group + one-line note.
      r = SingleHandFlow.resolveTarget(
          tracked: null, full: full, fullTableOpen: false);
      expect(r.target, isNull);
      expect(r.resumeUnavailable, isTrue);
      // Nothing running -> as before.
      r = SingleHandFlow.resolveTarget(
          tracked: null, full: null, fullTableOpen: false);
      expect(r.target, isNull);
      expect(r.resumeUnavailable, isFalse);
    });

    Future<SingleHandStart?> open(WidgetTester t, SingleHandSetup setup,
        {SingleHandSessionTarget? target, String? note}) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      SingleHandStart? result;
      await t.pumpWidget(_app(Builder(
        builder: (c) => TextButton(
          onPressed: () async => result = await SingleHandSetupScreen.show(c,
              setup: setup, session: target, note: note),
          child: const Text('open'),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Start hand'));
      await t.pumpAndSettle();
      return result;
    }

    testWidgets('the line says resume table; the game type is NOT locked',
        (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(SingleHandSetupScreen(
          setup: SingleHandSetup(
              gameType: GameType.tournament, smallBlind: 100, bigBlind: 200),
          session: full)));
      await t.pumpAndSettle();
      expect(find.text('Saving to Home game (resume table)'), findsOneWidget);
      expect(find.textContaining('Tourney'), findsOneWidget); // not forced
    });

    testWidgets('Start with the full session returns it (flow resumes)',
        (t) async {
      final r = await open(t, SingleHandSetup(), target: full);
      expect(r?.session?.isFull, isTrue);
      expect(r?.session?.id, 'f');
    });

    testWidgets('no resumable table: one-line note, hand goes to a group',
        (t) async {
      final r = await open(t, SingleHandSetup(),
          note: 'That session\'s table can\'t be resumed after the app '
              'restarted. Saving to a hand group.');
      expect(find.byKey(const ValueKey('setup-note')), findsNothing); // closed
      expect(r?.session, isNull);
    });

    testWidgets('the note is shown on the setup screen', (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(SingleHandSetupScreen(
          setup: SingleHandSetup(), note: 'Saving to a hand group.')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-note')), findsOneWidget);
    });

    testWidgets('popTo brings the full table back to the top', (t) async {
      late NavigatorState nav;
      await t.pumpWidget(_app(Builder(builder: (c) {
        nav = Navigator.of(c);
        return const Text('home');
      })));
      final table =
          MaterialPageRoute<void>(builder: (_) => const Text('table'));
      SessionNavigation.track(SessionNavigation.fullHubKey, table);
      nav.push(table);
      await t.pumpAndSettle();
      nav.push(MaterialPageRoute<void>(builder: (_) => const Text('setup')));
      await t.pumpAndSettle();
      expect(SessionNavigation.popTo(nav, SessionNavigation.fullHubKey), isTrue);
      await t.pumpAndSettle();
      expect(find.text('table'), findsOneWidget);
      expect(find.text('setup'), findsNothing);
    });

    test('after the table is gone popTo reports it', () {
      expect(SessionNavigation.isOpen(SessionNavigation.fullHubKey), isFalse);
    });
  });

  test('a running tracked session is the default target (verified, D)', () async {
    TrackedSessionService.currentRecord = () async => LiveSessionRecord(
        sessionId: 't', name: 'Casino', gameType: 'cash', startTime: DateTime.now());
    final r = await TrackedSessionService.runningTarget();
    expect(r?.id, 't');
    expect(r?.isFull, isFalse);
    expect(await TrackedSessionService.runningFullTarget(), isNull);
  });
}
