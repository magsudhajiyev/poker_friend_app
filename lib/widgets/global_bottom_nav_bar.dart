import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;
import '../screens/home_screen.dart';
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
          ClipRRect(
            borderRadius: BorderRadius.circular(70),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                width: 268,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(70),
                  border: Border.all(
                    color: const Color(0xFFA4B3A8).withOpacity(0.3),
                    width: 0.5,
                  ),
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
                            MaterialPageRoute(builder: (context) => HomeScreen()),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3A3A3C) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _buildIcon(
            iconPath,
            28,
            isActive ? Colors.white : const Color(0xFF636366),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
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
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFF5CD9A4),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _buildIcon(
            'icons/flat_icons/plus.png',
            28,
            const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }
}
