import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/logging_mode_selection_screen.dart';
import '../screens/club/club_dashboard_screen.dart';
import '../screens/player/qr_scan_screen.dart' show QRScanScreen;
import '../design_system/constants/colors.dart';
import '../services/club_service.dart';

/// Nav bar — Figma node 139:1186
/// Layout: [Home | Clubs | Opponents | Statistics | Scan] ··· [+ FAB]
/// Active icon: green (#4CDE78). Inactive: gray (#808285).
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

  static const Color _activeColor = Color(0xFF4CDE78);
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
                path: 'icons/figma_icons/club_suit.svg',
                isSvg: true,
                isActive: _isActive('clubs'),
                onTap: () => _navigateToClubs(context),
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
                path: 'icons/figma_icons/chart_regular.svg',
                isSvg: true,
                isActive: _isActive('sessions'),
                itemKey: widget.sessionsKey,
                onTap: () => _navigateTo(context, 'sessions'),
              ),
              const SizedBox(width: 28),
              _NavIcon(
                path: 'icons/flat_icons/scanner.png',
                isSvg: false,
                isActive: _isActive('scan'),
                onTap: () => _navigateTo(context, 'scan'),
              ),
            ],
          ),

          // Right: white circle FAB (44px)
          GestureDetector(
            key: widget.fabKey,
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              if (widget.onNavigationAttempt != null) {
                final ok = await widget.onNavigationAttempt!();
                if (!ok) return;
              }
              if (context.mounted) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    barrierColor: Colors.transparent,
                    transitionDuration: const Duration(milliseconds: 400),
                    reverseTransitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (_, __, ___) => LoggingModeSelectionScreen(),
                    transitionsBuilder: (_, animation, __, child) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      ));
                      return Stack(
                        children: [
                          // Blur fades in/out — does not slide
                          FadeTransition(
                            opacity: animation,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(color: Colors.black.withValues(alpha: 0.15)),
                            ),
                          ),
                          // White panel slides up/down
                          SlideTransition(
                            position: slide,
                            child: child,
                          ),
                        ],
                      );
                    },
                  ),
                );
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'icons/figma_icons/plus.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                ),
              ),
            ),
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
      case 'sessions':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SessionHistoryScreen()),
        );
        break;
      case 'scan':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QRScanScreen()),
        );
        break;
    }

    if (mounted) setState(() => _pendingScreen = null);
  }

  Future<void> _navigateToClubs(BuildContext context) async {
    if (widget.currentScreen == 'clubs') return;
    if (widget.onNavigationAttempt != null) {
      final ok = await widget.onNavigationAttempt!();
      if (!ok) return;
    }
    if (!context.mounted) return;

    setState(() => _pendingScreen = 'clubs');
    final clubs = await ClubService.getClubs();
    if (!context.mounted) return;
    if (clubs.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubDashboardScreen(club: clubs.first)),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/Info.svg',
                  width: 12,
                  height: 12,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF9A9B9E),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "You're not a member of any clubs yet",
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB9B9B9),
                    height: 16 / 11,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2C2C2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            duration: const Duration(seconds: 3),
          ),
        );
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
