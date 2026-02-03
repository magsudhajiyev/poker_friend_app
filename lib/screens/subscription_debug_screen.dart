import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';

/// Debug screen for testing subscription functionality
class SubscriptionDebugScreen extends StatelessWidget {
  const SubscriptionDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription Debug',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bug_report,
                color: Color(0xFFE67E22),
                size: 64,
              ),
              SizedBox(height: 24),
              Text(
                'Subscription Debug',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
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
    );
  }
}
