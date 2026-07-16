import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../screens/home_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/notifications_screen.dart';
import 'global_bottom_nav_bar.dart';

/// Persistent tab shell — the four content tabs live inside an
/// `IndexedStack` so tab switching is a `setState` instead of a route
/// push. The bottom nav bar is owned by the shell and never rebuilds
/// on tab switch. Scan and the "+" FAB still open as pushed routes.
class MainShell extends StatefulWidget {
  static final GlobalKey<MainShellState> globalKey =
      GlobalKey<MainShellState>();

  final int initialIndex;

  MainShell({this.initialIndex = 0}) : super(key: globalKey);

  @override
  State<MainShell> createState() => MainShellState();

  /// Look up the shell state from a descendant widget.
  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();
}

class MainShellState extends State<MainShell> {
  static const _screens = [
    'home',
    'opponents',
    'statistics',
    'sessions',
    'notifications',
  ];

  int _currentIndex = 0;
  // Start hidden — HomeScreen shows nav once its data is loaded, preventing
  // a single-frame nav flash during the loading splash.
  bool _navVisible = false;
  final GlobalKey fabKey = GlobalKey(debugLabel: 'shell-fab');
  final GlobalKey sessionsNavKey = GlobalKey(debugLabel: 'shell-sessions-nav');
  /// Fires when the Sessions tab becomes visible — used by
  /// SessionHistoryScreen to trigger the phase-6 onboarding tour.
  final ValueNotifier<int> sessionsTabNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  String get currentScreen => _screens[_currentIndex];

  /// Switch to a tab by its screen ID. Returns true if the tab changed.
  bool setTabByScreen(String screen) {
    final idx = _screens.indexOf(screen);
    if (idx < 0 || idx == _currentIndex) return false;
    setState(() => _currentIndex = idx);
    if (screen == 'sessions') {
      sessionsTabNotifier.value++;
    }
    return true;
  }

  /// Show or hide the bottom nav — used by descendant screens that open a
  /// bottom-anchored modal and want the nav out of the way.
  void setNavVisible(bool visible) {
    if (_navVisible == visible) return;
    setState(() => _navVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(),
              MyOpponentsScreen(),
              StatisticsScreen(),
              SessionHistoryScreen(),
              const NotificationsScreen(),
            ],
          ),
          // Bottom fade: content scrolling behind the nav dims into
          // bgPrimary instead of clipping at the nav edge. The bottom
          // half of the gradient sits behind the nav (invisible); the top
          // ~80px is the visible fade above the nav.
          if (_navVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 180,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.bgPrimary.withOpacity(0),
                        AppColors.bgPrimary.withOpacity(0.6),
                        AppColors.bgPrimary,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _navVisible
          ? GlobalBottomNavBar(
              currentScreen: currentScreen,
              fabKey: fabKey,
              sessionsKey: sessionsNavKey,
            )
          : null,
    );
  }
}
