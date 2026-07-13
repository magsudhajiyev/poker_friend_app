import 'package:flutter/material.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/constants/colors.dart';
import '../design_system/poker_friend_theme.dart';

/// Debug screen for testing subscription functionality
class SubscriptionDebugScreen extends StatelessWidget {
  const SubscriptionDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          TopNavBar(
            title: 'Subscription Debug',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bug_report,
                      color: Color(0xFFE67E22),
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Subscription Debug',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This screen is for testing subscription functionality.\nComing soon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PokerFriendColors.dark9,
                        fontSize: 14,
                      ),
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
}
