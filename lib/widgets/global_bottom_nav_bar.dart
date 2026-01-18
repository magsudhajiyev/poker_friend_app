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
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home Icon
          IconButton(
            icon: Icon(
              Icons.home,
              color: currentScreen == 'home' ? const Color(0xFFA5EC44) : Colors.white,
              size: 28,
            ),
            onPressed: () {
              if (currentScreen != 'home') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreenExperimental()),
                );
              }
            },
          ),
          // Opponents Icon
          IconButton(
            icon: Icon(
              Icons.group,
              color: currentScreen == 'opponents' ? const Color(0xFFA5EC44) : Colors.white,
              size: 28,
            ),
            onPressed: () {
              if (currentScreen != 'opponents') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyOpponentsScreen()),
                );
              }
            },
          ),
          // Center Plus Button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFA5EC44),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
                );
              },
            ),
          ),
          // Game/Sessions Icon
          IconButton(
            icon: Icon(
              Icons.style,
              color: currentScreen == 'sessions' ? const Color(0xFFA5EC44) : Colors.white,
              size: 28,
            ),
            onPressed: () {
              if (currentScreen != 'sessions') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
                );
              }
            },
          ),
          // Profile Icon
          IconButton(
            icon: Icon(
              Icons.person,
              color: currentScreen == 'profile' ? const Color(0xFFA5EC44) : Colors.white,
              size: 28,
            ),
            onPressed: () {
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
    );
  }
}
