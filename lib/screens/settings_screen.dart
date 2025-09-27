import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/poker_friend_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool useButtonMode = false;
  bool autoAdvanceStreets = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useButtonMode = prefs.getBool('use_button_mode') ?? false;
      autoAdvanceStreets = prefs.getBool('auto_advance_streets') ?? false;
    });
  }

  Future<void> _saveButtonMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_button_mode', value);
    setState(() {
      useButtonMode = value;
    });
  }

  Future<void> _saveAutoAdvanceStreets(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_advance_streets', value);
    setState(() {
      autoAdvanceStreets = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 375),
            margin: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section - matching home screen style
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Customize your experience',
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

                // Input Method Card
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PokerFriendColors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              useButtonMode ? Icons.smart_button : Icons.touch_app,
                              color: PokerFriendColors.red,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Input Method',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  useButtonMode ? 'Action Buttons' : 'Gesture Mode',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: PokerFriendColors.dark9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: useButtonMode,
                            onChanged: _saveButtonMode,
                            activeColor: PokerFriendColors.red,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: PokerFriendColors.dark4,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PokerFriendColors.dark1,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              useButtonMode ? 'Button Mode Features:' : 'Gesture Mode Features:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            if (useButtonMode) ...[
                              _buildFeatureText('• Tap action buttons to play hands'),
                              _buildFeatureText('• Clear visual feedback for each action'),
                              _buildFeatureText('• Perfect for new users'),
                            ] else ...[
                              _buildFeatureText('• Draw gestures on the screen'),
                              _buildFeatureText('• Tap = Bet/Raise, Circle = Call, X = Fold'),
                              _buildFeatureText('• Faster input for experienced users'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Game Flow Card
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PokerFriendColors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              autoAdvanceStreets ? Icons.fast_forward : Icons.pause,
                              color: PokerFriendColors.red,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game Flow',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  autoAdvanceStreets ? 'Auto-Advance Mode' : 'Manual Mode',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: PokerFriendColors.dark9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: autoAdvanceStreets,
                            onChanged: _saveAutoAdvanceStreets,
                            activeColor: PokerFriendColors.red,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: PokerFriendColors.dark4,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PokerFriendColors.dark1,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              autoAdvanceStreets ? 'Auto-Advance Features:' : 'Manual Mode Features:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            if (autoAdvanceStreets) ...[
                              _buildFeatureText('• Game automatically moves from Preflop → Flop → Turn → River'),
                              _buildFeatureText('• Saves time during rapid gameplay'),
                              _buildFeatureText('• Perfect for experienced players'),
                            ] else ...[
                              _buildFeatureText('• Full control over game progression'),
                              _buildFeatureText('• Take time to analyze each street'),
                              _buildFeatureText('• Ideal for learning and review'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureText(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: PokerFriendColors.dark9,
          height: 1.4,
        ),
      ),
    );
  }
}