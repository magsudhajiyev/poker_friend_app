import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/home_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/logging_mode_selection_screen.dart';
import '../screens/player/qr_scan_screen.dart' show QRScanScreen;
import '../design_system/constants/colors.dart';
import 'main_shell.dart';

/// Nav bar — Figma node 139:1182
/// Layout: [Home | Opponents | Statistics | Sessions | Scan] ··· [+ FAB]
/// Active icon: brand green (accentPrimary). Inactive: gray (#808285).
/// FAB: 44px circle, bgElevated (#2C2C2E), white plus icon.
class GlobalBottomNavBar extends StatefulWidget {
  final String currentScreen;
  final Future<bool> Function()? onNavigationAttempt;
  final GlobalKey? fabKey;
  final GlobalKey? sessionsKey;

  const GlobalBottomNavBar({
    Key? key,
    required this.currentScreen,
    this.onNavigationAttempt,
    this.fabKey,
    this.sessionsKey,
  }) : super(key: key);

  static const Color _activeColor = AppColors.accentPrimary;
  static const Color _inactiveColor = Color(0xFF808285);

  @override
  State<GlobalBottomNavBar> createState() => _GlobalBottomNavBarState();
}

class _GlobalBottomNavBarState extends State<GlobalBottomNavBar> {
  String? _pendingScreen;

  bool _isActive(String screen) =>
      widget.currentScreen == screen || _pendingScreen == screen;

  @override
  Widget build(BuildContext context) {
    final double systemBottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      color: AppColors.bgPrimary, // #0c0c0c
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + systemBottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: 5 icon buttons, gap 28px
          Row(
            children: [
              _NavIcon(
                path: 'assets/icons/HouseSimple.svg',
                isSvg: true,
                isActive: _isActive('home'),
                onTap: () => _navigateTo(context, 'home'),
              ),
              const SizedBox(width: 28),
              _NavIcon(
                path: 'assets/icons/UsersThree.svg',
                activePath: 'assets/icons/UsersThree-1.svg',
                isSvg: true,
                isActive: _isActive('opponents'),
                onTap: () => _navigateTo(context, 'opponents'),
              ),
              const SizedBox(width: 28),
              _NavIcon(
                path: 'assets/icons/ChartBar.svg',
                activePath: 'assets/icons/ChartBar-1.svg',
                isSvg: true,
                isActive: _isActive('statistics'),
                onTap: () => _navigateTo(context, 'statistics'),
              ),
              const SizedBox(width: 28),
              _NavIcon(
                path: 'icons/figma_icons/clock.svg',
                activePath: 'assets/icons/card icons/Clock filled.svg',
                isSvg: true,
                isActive: _isActive('sessions'),
                itemKey: widget.sessionsKey,
                onTap: () => _navigateTo(context, 'sessions'),
              ),
              const SizedBox(width: 28),
              _NavIcon(
                path: 'icons/flat_icons/scanner.png',
                activePath: 'assets/icons/card icons/Frame.svg',
                isSvg: false,
                isActive: _isActive('scan'),
                onTap: () => _navigateTo(context, 'scan'),
              ),
            ],
          ),

          // Right: circle FAB (44px) with tactile press animation
          _FabButton(
            fabKey: widget.fabKey,
            onTap: () async {
              if (widget.onNavigationAttempt != null) {
                final ok = await widget.onNavigationAttempt!();
                if (!ok) return;
              }
              if (context.mounted) {
                Navigator.push(
                  context,
                  LoggingModeSelectionScreen.route(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateTo(BuildContext context, String screen) async {
    if (widget.currentScreen == screen) return;
    if (widget.onNavigationAttempt != null) {
      final ok = await widget.onNavigationAttempt!();
      if (!ok) return;
    }
    if (!context.mounted) return;

    // Scan is a one-shot pushed screen, not a persistent tab.
    if (screen == 'scan') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QRScanScreen()),
      );
      return;
    }

    // Shell-aware routing: if we're inside (or beneath) a MainShell, switch
    // its tab instead of pushing a new route so the nav bar doesn't animate
    // away. If we're on a pushed detail screen, first pop back to the shell.
    final shell = MainShell.globalKey.currentState;
    if (shell != null) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      shell.setTabByScreen(screen);
      return;
    }

    // Legacy fallback (used only if there's no MainShell in the tree).
    setState(() => _pendingScreen = screen);
    switch (screen) {
      case 'home':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
        break;
      case 'opponents':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MyOpponentsScreen()),
        );
        break;
      case 'statistics':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StatisticsScreen()),
        );
        break;
      case 'sessions':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SessionHistoryScreen()),
        );
        break;
    }

    if (mounted) setState(() => _pendingScreen = null);
  }

}

/// Single nav icon button — 28×28 touch target.
/// When [activePath] is provided, that SVG is shown as-is (native colors)
/// when the icon is active, and [path] is shown with the inactive color filter
/// when inactive.
class _NavIcon extends StatelessWidget {
  final String path;
  final String? activePath;
  final bool isSvg;
  final bool isActive;
  final VoidCallback onTap;
  final GlobalKey? itemKey;

  const _NavIcon({
    required this.path,
    required this.isSvg,
    required this.isActive,
    required this.onTap,
    this.activePath,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    // When an activePath is provided and the icon is active, render it
    // without any color filter so the SVG's own fill colors show through.
    final useActivePath = isActive && activePath != null;
    final resolvedPath = useActivePath ? activePath! : path;
    final color = isActive
        ? GlobalBottomNavBar._activeColor
        : GlobalBottomNavBar._inactiveColor;

    // Renderer is chosen per resolved path so the active/inactive pair
    // may mix formats (e.g. scan tab: PNG inactive, SVG active).
    final resolvedIsSvg = resolvedPath.toLowerCase().endsWith('.svg');

    return GestureDetector(
      key: itemKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: resolvedIsSvg
              ? SvgPicture.asset(
                  resolvedPath,
                  width: 28,
                  height: 28,
                  colorFilter: useActivePath
                      ? null
                      : ColorFilter.mode(color, BlendMode.srcIn),
                )
              : Image.asset(
                  resolvedPath,
                  width: 28,
                  height: 28,
                  color: useActivePath ? null : color,
                ),
        ),
      ),
    );
  }
}


/// 44×44 bgElevated FAB circle with an obvious tactile press animation:
/// scales to 1.28× with a spring-back curve so the tap is unmistakably
/// registered by the user.
class _FabButton extends StatefulWidget {
  final GlobalKey? fabKey;
  final Future<void> Function() onTap;

  const _FabButton({required this.fabKey, required this.onTap});

  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.fabKey,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 1.28 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _pressed ? AppColors.accentPrimary : AppColors.bgElevated,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              'icons/figma_icons/plus.svg',
              width: 25,
              height: 25,
              colorFilter: ColorFilter.mode(
                _pressed ? AppColors.textInverse : AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
