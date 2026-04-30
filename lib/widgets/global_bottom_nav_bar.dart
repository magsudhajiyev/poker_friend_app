import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
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
  Widget build(BuildContext context) {
    // The FAB overflows 30px above the navbar. We include that space in the
    // widget's own height so the Scaffold doesn't clip it.
    return SizedBox(
      height: 30 + 14 + 51 + 18, // fabOverflow + topPad + content + bottomPad
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Navbar background — positioned at the bottom, below the FAB overflow area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Home
                      _buildNavItem(
                        context: context,
                        iconPath: 'icons/figma_icons/navbar_home.svg',
                        label: l10n.navHome,
                        isActive: currentScreen == 'home',
                        onTap: () => _navigateTo(context, 'home'),
                      ),

                      // Opponents
                      _buildNavItem(
                        context: context,
                        iconPath: 'icons/figma_icons/navbar_opponents.svg',
                        label: l10n.navOpponents,
                        isActive: currentScreen == 'opponents',
                        onTap: () => _navigateTo(context, 'opponents'),
                      ),

                      // Center spacer
                      const SizedBox(width: 62, height: 51),

                      // Sessions
                      _buildNavItem(
                        context: context,
                        iconPath: 'icons/figma_icons/navbar_sessions.svg',
                        label: l10n.navSessions,
                        isActive: currentScreen == 'sessions',
                        onTap: () => _navigateTo(context, 'sessions'),
                        itemKey: sessionsKey,
                      ),

                      // Profile
                      _buildNavItem(
                        context: context,
                        iconPath: 'icons/figma_icons/navbar_profile.svg',
                        label: l10n.navProfile,
                        isActive: currentScreen == 'profile',
                        onTap: () => _navigateTo(context, 'profile'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Center FAB button — top of the SizedBox, centered horizontally
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCenterFab(context),
            ),
          ),
        ],
      ),
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
  Widget _buildNavItem({
    required BuildContext context,
    required String iconPath,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    GlobalKey? itemKey,
  }) {
    final color = isActive
        ? const Color(0xFF89F1EC)
        : const Color(0xFF808285);

    return GestureDetector(
      key: itemKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: color,
                  height: 1.47,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Center FAB button
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
        key: fabKey,
        width: 62,
        height: 62,
        decoration: const BoxDecoration(
          color: Color(0xFF1B1E24),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 49,
            height: 49,
            decoration: const BoxDecoration(
              color: Color(0xFF89F1EC),
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
