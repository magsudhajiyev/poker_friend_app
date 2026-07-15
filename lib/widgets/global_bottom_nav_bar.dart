import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/home_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/logging_mode_selection_screen.dart';
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

  static const _tabOrder = [
    'home',
    'opponents',
    'statistics',
    'sessions',
    'notifications',
  ];

  int _activeIndex() {
    final key = _pendingScreen ?? widget.currentScreen;
    final i = _tabOrder.indexOf(key);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    // Figma node 1884:15154 — segmented glass pill (5 tabs) on the left,
    // separate glass FAB on the right. No solid outer container fill;
    // the pill and FAB each host their own BackdropFilter.
    //
    // Small fixed breather (12px) so the pill clears the iOS home
    // indicator without floating high above it. On devices without an
    // indicator this just reads as extra bottom margin.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _NavPill(
            activeIndex: _activeIndex(),
            items: [
              _NavItemData(
                icon: 'assets/icons/HouseSimple.svg',
                onTap: () => _navigateTo(context, 'home'),
              ),
              _NavItemData(
                icon: 'assets/icons/UsersThree.svg',
                onTap: () => _navigateTo(context, 'opponents'),
              ),
              _NavItemData(
                icon: 'assets/icons/ChartBar.svg',
                onTap: () => _navigateTo(context, 'statistics'),
              ),
              _NavItemData(
                icon: 'icons/figma_icons/clock.svg',
                itemKey: widget.sessionsKey,
                onTap: () => _navigateTo(context, 'sessions'),
              ),
              _NavItemData(
                icon: 'assets/icons/bell.svg',
                onTap: () => _navigateTo(context, 'notifications'),
              ),
            ],
          ),
          _GlassFab(
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

/// Data for one entry in [_NavPill].
class _NavItemData {
  final String icon;
  final VoidCallback onTap;
  final GlobalKey? itemKey;

  const _NavItemData({
    required this.icon,
    required this.onTap,
    this.itemKey,
  });
}

/// Segmented glass pill hosting the 5 tab items. Figma node 1884:15154.
///
/// - Backdrop-blur (22) + white @ 6% fill + 999px radius
/// - 12h / 7v inner padding, 8px gap between items
/// - Each item: 28px icon (top) + 10px label (below)
/// - Active state: a rounded-rect background (62×48, radius 80, white @ 16%)
///   slides between items with `Curves.easeOutBack`
class _NavPill extends StatefulWidget {
  final int activeIndex;
  final List<_NavItemData> items;

  static const double _itemWidth = 44;
  static const double _itemHeight = 44;
  static const double _itemGap = 8;
  static const double _hPad = 10;
  static const double _vPad = 6;
  static const double _highlightW = 48;
  static const double _highlightH = 48;

  const _NavPill({required this.activeIndex, required this.items});

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  // Whole-pill press state — driven by a `Listener` above the pill so
  // any tap anywhere on it triggers the scale-down. The individual
  // items still handle their own icon press animation independently,
  // giving a nice layered "pill acknowledges + icon punches" effect.
  bool _pillPressed = false;

  void _setPillPressed(bool value) {
    if (!mounted || _pillPressed == value) return;
    setState(() => _pillPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // The highlight is 62px wide (12px wider than an item slot); center it
    // over the active item — that means the highlight's left = item.center - 31.
    final activeCenter = widget.activeIndex *
            (_NavPill._itemWidth + _NavPill._itemGap) +
        _NavPill._itemWidth / 2;
    final highlightLeft = activeCenter - _NavPill._highlightW / 2;

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPillPressed(true),
      onPointerUp: (_) => _setPillPressed(false),
      onPointerCancel: (_) => _setPillPressed(false),
      child: AnimatedScale(
        scale: _pillPressed ? 0.97 : 1.0,
        duration: _pillPressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 380),
        curve: _pillPressed ? Curves.easeOut : Curves.easeOutBack,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _NavPill._hPad,
                vertical: _NavPill._vPad,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Sliding highlight rectangle behind the active item —
                  // centered vertically within the item row.
                  AnimatedPositioned(
                    left: highlightLeft,
                    top: (_NavPill._itemHeight - _NavPill._highlightH) /
                        2,
                    width: _NavPill._highlightW,
                    height: _NavPill._highlightH,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(80),
                      ),
                    ),
                  ),
                  // Items row.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.items.length; i++) ...[
                        if (i > 0) SizedBox(width: _NavPill._itemGap),
                        _NavPillItem(
                          data: widget.items[i],
                          isActive: i == widget.activeIndex,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single nav-pill tab. Stateful so we can layer two icon animations:
///
/// 1. **Press-in / spring-back** — tap-down snaps to 0.82 (fast easeOut,
///    90ms); tap-up springs back to 1.0 with a subtle `easeOutBack`
///    overshoot (420ms). Reads as a physical button push.
/// 2. **Active pop** — when [isActive] flips true, the resting scale
///    lifts to 1.08 with an elastic settle so the newly-selected tab
///    briefly bounces above its neighbors.
///
/// The whole pill also reacts to any tap on it (see `_NavPill`), and a
/// selection-click haptic fires on every tap so the finger always gets
/// a tactile confirmation regardless of whether the tab actually
/// changed. Icons stay white — selection is communicated by the sliding
/// highlight underneath and the active pop, not by colour.
class _NavPillItem extends StatefulWidget {
  final _NavItemData data;
  final bool isActive;

  const _NavPillItem({required this.data, required this.isActive});

  @override
  State<_NavPillItem> createState() => _NavPillItemState();
}

class _NavPillItemState extends State<_NavPillItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  double get _targetScale {
    if (_pressed) return 0.82;
    return widget.isActive ? 1.08 : 1.0;
  }

  Duration get _scaleDuration => _pressed
      ? const Duration(milliseconds: 90)
      : const Duration(milliseconds: 420);

  Curve get _scaleCurve =>
      _pressed ? Curves.easeOut : Curves.easeOutBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.data.itemKey,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.data.onTap();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _targetScale,
        duration: _scaleDuration,
        curve: _scaleCurve,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: _iconGlyph(widget.data.icon)),
        ),
      ),
    );
  }

  Widget _iconGlyph(String path) {
    final isSvg = path.toLowerCase().endsWith('.svg');
    return SizedBox(
      width: 28,
      height: 28,
      child: isSvg
          ? SvgPicture.asset(
              path,
              width: 28,
              height: 28,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            )
          : Image.asset(
              path,
              width: 28,
              height: 28,
              color: Colors.white,
            ),
    );
  }
}

/// 56×56 glass FAB — backdrop-blur (27) + white @ 6% fill. Figma node
/// 1884:15164. Retains the tap scale animation.
class _GlassFab extends StatefulWidget {
  final GlobalKey? fabKey;
  final Future<void> Function() onTap;

  const _GlassFab({required this.fabKey, required this.onTap});

  @override
  State<_GlassFab> createState() => _GlassFabState();
}

class _GlassFabState extends State<_GlassFab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.fabKey,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        // Grow-then-settle: 1.14 on press for a punchier reaction than
        // a static button, with easeOutBack for the spring-in feel.
        scale: _pressed ? 1.14 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 27, sigmaY: 27),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: _pressed ? 0.16 : 0.06,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'icons/figma_icons/plus.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
