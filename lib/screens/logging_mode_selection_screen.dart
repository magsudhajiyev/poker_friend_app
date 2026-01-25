import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../design_system/poker_friend_theme.dart';
import '../widgets/global_bottom_nav_bar.dart';
import 'introduction_screen.dart';
import 'individual_session_setup_screen.dart';
import '../design_system/design_system.dart';

class LoggingModeSelectionScreen extends StatelessWidget {
  const LoggingModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Screen Header with glassmorphic blur
                  MainScreenHeader(
                    title: 'Choose Mode',
                    subtitle: 'Select your logging preference',
                    rightIcon: Icons.close_rounded,
                    onRightPressed: () => Navigator.pop(context),
                    showLeftIcon: false,
                    padding: const EdgeInsets.all(16),
                  ),

                  // Mode Selection Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
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

                        SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: ''),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0x4C2C3E2E), // #2c3e2e4c - matches Figma design
        borderRadius: BorderRadius.circular(24),
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 7),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
          // Features section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Features:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 14),
              ...features.map((feature) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $feature',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFFF8FFF7), // #f8fff7 - matches Figma design
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                ),
              )).toList(),
            ],
          ),
          SizedBox(height: 32),
          // Log in button
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      height: 1.5,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.black,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
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