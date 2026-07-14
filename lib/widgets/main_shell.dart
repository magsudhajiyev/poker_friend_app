import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../screens/home_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/session_history_screen.dart';
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
  static const _screens = ['home', 'opponents', 'statistics', 'sessions'];

  int _currentIndex = 0;
  bool _navVisible = true;
  final GlobalKey fabKey = GlobalKey(debugLabel: 'shell-fab');
  final GlobalKey sessionsNavKey = GlobalKey(debugLabel: 'shell-sessions-nav');

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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(),
          MyOpponentsScreen(),
          StatisticsScreen(),
          SessionHistoryScreen(),
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
