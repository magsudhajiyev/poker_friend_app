import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import 'introduction_screen.dart';
import 'individual_session_setup_screen.dart';

class LoggingModeSelectionScreen extends StatelessWidget {
  const LoggingModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Container(
          constraints: BoxConstraints(maxWidth: 375),
          margin: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: EdgeInsets.fromLTRB(0, 32, 0, 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Mode',
                          style: TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select your logging preference',
                          style: TextStyle(
                            fontSize: 16,
                            color: PokerFriendColors.dark9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: PokerFriendColors.dark3,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mode Selection Cards
              Expanded(
                child: Column(
                  children: [
                    // Full Logging Mode Card
                    _buildModeCard(
                      context: context,
                      title: 'Full Logging Mode',
                      subtitle: 'Complete session tracking',
                      description: 'Track entire poker sessions with multiple hands, detailed statistics, and comprehensive analysis.',
                      iconPath: 'icons/notebook.png',
                      features: [
                        'Multi-hand session tracking',
                        'Real-time statistics',
                        'Detailed hand history',
                        'Session analytics'
                      ],
                      onTap: () => _navigateToMode(context, LoggingMode.full),
                    ),

                    SizedBox(height: 24),

                    // Individual Logging Mode Card
                    _buildModeCard(
                      context: context,
                      title: 'Individual Logging Mode',
                      subtitle: 'Single hand tracking',
                      description: 'Log individual hands quickly and efficiently. Perfect for spot tracking or specific hand analysis.',
                      iconPath: 'icons/notepad.png',
                      features: [
                        'Single hand focus',
                        'Quick logging',
                        'Hand analysis',
                        'Instant results'
                      ],
                      onTap: () => _navigateToMode(context, LoggingMode.individual),
                    ),

                    Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required String iconPath,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: PokerFriendColors.dark4,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  child: Image.asset(
                    iconPath,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: PokerFriendColors.dark9,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: PokerFriendColors.dark9,
                  size: 16,
                ),
              ],
            ),

            SizedBox(height: 16),

            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: PokerFriendColors.dark10,
                height: 1.4,
              ),
            ),

            SizedBox(height: 16),

            // Features List
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PokerFriendColors.dark1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...features.map((feature) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: PokerFriendColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          feature,
                          style: TextStyle(
                            fontSize: 13,
                            color: PokerFriendColors.dark10,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMode(BuildContext context, LoggingMode mode) {
    // Both modes now go to Session Setup first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualSessionSetupScreen(
          loggingMode: mode,
        ),
      ),
    );
  }
}

enum LoggingMode {
  full,
  individual,
}