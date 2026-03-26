import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/logging_mode_selection_screen.dart';

/// Global bottom navigation bar matching Figma design (node 370:4719)
/// Full width with menu item labels
class GlobalBottomNavBar extends StatelessWidget {
  final String currentScreen;
  final Future<bool> Function()? onNavigationAttempt;

  const GlobalBottomNavBar({
    Key? key,
    required this.currentScreen,
    this.onNavigationAttempt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF02050B), // backgroundPaper
        border: Border(
          top: BorderSide(
            color: Color(0xFF1B1E24), // neutrals/800
            width: 1,
          ),
        ),
      ),
      // Figma: pb-18, pt-14, px-24
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Menu items row - uses spaceEvenly for responsive layout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Home
              _buildNavItem(
                context: context,
                iconPath: 'icons/figma_icons/navbar_home.svg',
                label: 'Home',
                isActive: currentScreen == 'home',
                onTap: () => _navigateTo(context, 'home'),
              ),

              // Opponents
              _buildNavItem(
                context: context,
                iconPath: 'icons/figma_icons/navbar_opponents.svg',
                label: 'Opponents',
                isActive: currentScreen == 'opponents',
                onTap: () => _navigateTo(context, 'opponents'),
              ),

              // Center spacer for FAB - tappable area for the visible portion
              GestureDetector(
                onTap: () => _onFabTap(context),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(width: 62, height: 51),
              ),

              // Sessions
              _buildNavItem(
                context: context,
                iconPath: 'icons/figma_icons/navbar_sessions.svg',
                label: 'Sessions',
                isActive: currentScreen == 'sessions',
                onTap: () => _navigateTo(context, 'sessions'),
              ),

              // Profile
              _buildNavItem(
                context: context,
                iconPath: 'icons/figma_icons/navbar_profile.svg',
                label: 'Profile',
                isActive: currentScreen == 'profile',
                onTap: () => _navigateTo(context, 'profile'),
              ),
            ],
          ),

          // Center FAB button - positioned above the bar (Figma: top: -30px)
          Positioned(
            left: 0,
            right: 0,
            top: -30,
            child: Center(
              child: _buildCenterFab(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onFabTap(BuildContext context) async {
    if (onNavigationAttempt != null) {
      final shouldProceed = await onNavigationAttempt!();
      if (!shouldProceed) return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
    );
  }

  Future<void> _navigateTo(BuildContext context, String screen) async {
    if (currentScreen == screen) return;

    if (onNavigationAttempt != null) {
      final shouldProceed = await onNavigationAttempt!();
      if (!shouldProceed) return;
    }

    Widget destination;
    switch (screen) {
      case 'home':
        destination = HomeScreen();
        break;
      case 'opponents':
        destination = MyOpponentsScreen();
        break;
      case 'sessions':
        destination = SessionHistoryScreen();
        break;
      case 'profile':
        destination = ProfileScreen();
        break;
      default:
        return;
    }

    if (screen == 'home') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    }
  }

  /// Nav item with icon and label
  /// Figma: w-66px, flex-col, items-center
  Widget _buildNavItem({
    required BuildContext context,
    required String iconPath,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    // Cyan when active, gray when inactive
    final color = isActive
        ? const Color(0xFF89F1EC)  // mint/300 - cyan
        : const Color(0xFF808285); // neutrals/400 - gray

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container (32x32, rounded)
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ),
            // Label
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: color,
                height: 1.47,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Center FAB button
  /// Figma: outer 62x62 #1B1E24, inner ~49x49 #89F1EC
  Widget _buildCenterFab(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (onNavigationAttempt != null) {
          final shouldProceed = await onNavigationAttempt!();
          if (!shouldProceed) return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
        );
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: const BoxDecoration(
          color: Color(0xFF1B1E24), // neutrals/800
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 49,
            height: 49,
            decoration: const BoxDecoration(
              color: Color(0xFF89F1EC), // mint/300
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'icons/figma_icons/plus.svg',
                width: 27,
                height: 27,
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
