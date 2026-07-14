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

  @override
  State<GlobalBottomNavBar> createState() => _GlobalBottomNavBarState();
}

class _GlobalBottomNavBarState extends State<GlobalBottomNavBar> {
  String? _pendingScreen;

  static const _tabOrder = ['home', 'opponents', 'statistics', 'sessions', 'scan'];

  int _activeIndex() {
    final key = _pendingScreen ?? widget.currentScreen;
    final i = _tabOrder.indexOf(key);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final double systemBottomPad = MediaQuery.of(context).viewPadding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: AppColors.bgPrimary.withValues(alpha: 0.7),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + systemBottomPad),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: 5 icon buttons behind a sliding ellipse pill that fluidly
          // transitions to the active tab.
          _SlidingIconRow(
            activeIndex: _activeIndex(),
            children: [
              _NavIcon(
                path: 'assets/icons/HouseSimple.svg',
                onTap: () => _navigateTo(context, 'home'),
              ),
              _NavIcon(
                path: 'assets/icons/UsersThree.svg',
                onTap: () => _navigateTo(context, 'opponents'),
              ),
              _NavIcon(
                path: 'assets/icons/ChartBar.svg',
                onTap: () => _navigateTo(context, 'statistics'),
              ),
              _NavIcon(
                path: 'icons/figma_icons/clock.svg',
                itemKey: widget.sessionsKey,
                onTap: () => _navigateTo(context, 'sessions'),
              ),
              _NavIcon(
                path: 'icons/flat_icons/scanner.png',
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
        ),
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

/// Row of 5 [_NavIcon]s with a sliding ellipse pill that fluidly moves
/// behind the active tab. The pill uses `Curves.easeOutBack` for a bouncy
/// arrival at the new tab position.
class _SlidingIconRow extends StatelessWidget {
  final int activeIndex;
  final List<Widget> children;

  static const double _slotWidth = 40;
  static const double _slotHeight = 40;
  static const double _gap = 18;
  static const double _pillWidth = 52;
  static const double _pillHeight = 36;

  const _SlidingIconRow({required this.activeIndex, required this.children});

  @override
  Widget build(BuildContext context) {
    final totalW = children.length * _slotWidth + (children.length - 1) * _gap;
    final activeCenter =
        activeIndex * (_slotWidth + _gap) + _slotWidth / 2;

    return SizedBox(
      width: totalW,
      height: _slotHeight,
      child: Stack(
        alignment: Alignment.center,
        // Never clip children — the pill (52×36) intentionally overhangs
        // slot 0 and slot 4 by 6px on each side.
        clipBehavior: Clip.none,
        children: [
          // Sliding ellipse pill — glides between slots.
          AnimatedPositioned(
            left: activeCenter - _pillWidth / 2,
            top: (_slotHeight - _pillHeight) / 2,
            width: _pillWidth,
            height: _pillHeight,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // Icons row — inject the active flag into each _NavIcon so the
          // selected glyph tints green.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: _gap),
                SizedBox(
                  width: _slotWidth,
                  height: _slotHeight,
                  child: Center(
                    child: (children[i] is _NavIcon)
                        ? (children[i] as _NavIcon)
                            .copyWithActive(i == activeIndex)
                        : children[i],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Single nav icon button — 28×28 glyph.
///
/// Inactive tabs render in white; the active tab renders in
/// `accentSecondary` (green). The sliding pill behind lives in
/// [_SlidingIconRow] and is orthogonal to this widget.
class _NavIcon extends StatelessWidget {
  final String path;
  final VoidCallback onTap;
  final GlobalKey? itemKey;
  final bool isActive;

  const _NavIcon({
    required this.path,
    required this.onTap,
    this.itemKey,
    this.isActive = false,
  });

  _NavIcon copyWithActive(bool active) => _NavIcon(
        path: path,
        onTap: onTap,
        itemKey: itemKey,
        isActive: active,
      );

  @override
  Widget build(BuildContext context) {
    final isSvg = path.toLowerCase().endsWith('.svg');
    final color = isActive ? AppColors.accentSecondary : Colors.white;
    return GestureDetector(
      key: itemKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: isSvg
              ? SvgPicture.asset(
                  path,
                  width: 28,
                  height: 28,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              : Image.asset(
                  path,
                  width: 28,
                  height: 28,
                  color: color,
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
