import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/statistics_screen.dart';
import '../design_system/components.dart';

class GlobalTopHeader extends StatelessWidget {
  final String currentScreen;

  const GlobalTopHeader({
    Key? key,
    required this.currentScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile Picture
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        // Right side icons
        Row(
          children: [
            // Statistics Icon
            GestureDetector(
              onTap: () {
                if (currentScreen != 'statistics') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StatisticsScreen()),
                  );
                }
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: currentScreen == 'statistics'
                      ? const Color(0xFFA5EC44).withOpacity(0.2)
                      : Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: currentScreen == 'statistics'
                        ? const Color(0xFFA5EC44)
                        : Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Notification Bell Icon
            GlassyIconButton(
              icon: Icons.notifications,
              onPressed: () {
                // TODO: Navigate to notifications
              },
            ),
          ],
        ),
      ],
    );
  }
}
