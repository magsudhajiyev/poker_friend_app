import 'package:flutter/material.dart';
import '../screens/home_screen_experimental.dart';
import '../screens/statistics_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/logging_mode_selection_screen.dart';

class GlobalBottomNavBar extends StatelessWidget {
  final String currentScreen;

  const GlobalBottomNavBar({
    Key? key,
    required this.currentScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 268,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border.all(
                color: const Color(0xFF292F29),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(70),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 74,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Home Icon
                _buildNavItem(
                  iconPath: 'icons/flat_icons/home.png',
                  isActive: currentScreen == 'home',
                  onTap: () {
                    if (currentScreen != 'home') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomeScreenExperimental()),
                      );
                    }
                  },
                ),
                // Opponents Icon
                _buildNavItem(
                  iconPath: 'icons/flat_icons/people.png',
                  isActive: currentScreen == 'opponents',
                  onTap: () {
                    if (currentScreen != 'opponents') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyOpponentsScreen()),
                      );
                    }
                  },
                ),
                // Center Plus Button
                _buildPlusButton(context),
                // Game/Sessions Icon
                _buildNavItem(
                  iconPath: 'icons/flat_icons/cards.png',
                  isActive: currentScreen == 'sessions',
                  onTap: () {
                    if (currentScreen != 'sessions') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
                      );
                    }
                  },
                ),
                // Profile Icon
                _buildNavItem(
                  iconPath: 'icons/flat_icons/user.png',
                  isActive: currentScreen == 'profile',
                  onTap: () {
                    if (currentScreen != 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileScreen()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String iconPath,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Opacity(
            opacity: isActive ? 1.0 : 0.6,
            child: Image.asset(
              iconPath,
              width: 24,
              height: 24,
              color: isActive ? const Color(0xFF011100) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlusButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
        );
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFA5EC44),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0xD903350B),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            'icons/flat_icons/plus.png',
            width: 24,
            height: 24,
            color: const Color(0xFF011100),
          ),
        ),
      ),
    );
  }
}
