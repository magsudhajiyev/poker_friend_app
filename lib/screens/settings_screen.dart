import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../design_system/poker_friend_theme.dart';
import '../services/logger_service.dart';
import '../services/test_data_seed_service.dart';
import 'debug_hand_viewer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool autoAdvanceStreets = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoAdvanceStreets = prefs.getBool('auto_advance_streets') ?? false;
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

                SizedBox(height: 24),

                // Debug Logs Card
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
                              Icons.bug_report,
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
                                  'Debug Logs',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'View session logs for debugging',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: PokerFriendColors.dark9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // View Logs Button
                      _buildLogButton(
                        icon: Icons.text_snippet,
                        label: 'View Logs',
                        onPressed: _viewLogs,
                      ),
                      SizedBox(height: 12),

                      // Share Logs Button
                      _buildLogButton(
                        icon: Icons.share,
                        label: 'Share Logs',
                        onPressed: _shareLogs,
                      ),
                      SizedBox(height: 12),

                      // Clear Logs Button
                      _buildLogButton(
                        icon: Icons.delete_outline,
                        label: 'Clear Logs',
                        onPressed: _clearLogs,
                        isDestructive: true,
                      ),
                      SizedBox(height: 12),

                      // Debug Hand Viewer Button
                      _buildLogButton(
                        icon: Icons.search,
                        label: 'Debug Hand Viewer',
                        onPressed: _openDebugHandViewer,
                      ),
                      SizedBox(height: 12),

                      // Seed Test Data Button
                      _buildLogButton(
                        icon: Icons.data_array,
                        label: 'Seed Test Data (50 Hands)',
                        onPressed: _seedTestData,
                      ),
                      SizedBox(height: 12),

                      // Cleanup Test Data Button
                      _buildLogButton(
                        icon: Icons.delete_sweep,
                        label: 'Cleanup Test Data',
                        onPressed: _cleanupTestData,
                        isDestructive: true,
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

  Widget _buildLogButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? PokerFriendColors.red.withOpacity(0.3)
                : PokerFriendColors.dark4,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? PokerFriendColors.red : Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? PokerFriendColors.red : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Icon(
              Icons.chevron_right,
              color: PokerFriendColors.dark7,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewLogs() async {
    try {
      final logs = await LoggerService.exportLogs();
      final logSize = await LoggerService.getLogFileSize();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: PokerFriendColors.dark2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: 600),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.text_snippet,
                      color: PokerFriendColors.red,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Session Logs',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Size: ${logSize.toStringAsFixed(2)} MB',
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.dark9,
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.dark1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        logs,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: logs));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logs copied to clipboard'),
                              backgroundColor: PokerFriendColors.dark3,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PokerFriendColors.dark3,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Copy to Clipboard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading logs: $e'),
          backgroundColor: PokerFriendColors.red,
        ),
      );
    }
  }

  Future<void> _shareLogs() async {
    try {
      final logPath = await LoggerService.getLogFilePath();
      if (logPath != null) {
        await Share.shareXFiles(
          [XFile(logPath)],
          subject: 'Poker Logger Session Logs',
          text: 'Session logs from Poker Logger app',
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No log file found'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing logs: $e'),
          backgroundColor: PokerFriendColors.red,
        ),
      );
    }
  }

  void _openDebugHandViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DebugHandViewerScreen()),
    );
  }

  Future<void> _clearLogs() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Clear All Logs?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete all session logs. This action cannot be undone.',
          style: TextStyle(color: PokerFriendColors.dark9),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: PokerFriendColors.red,
            ),
            child: Text('Clear Logs'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LoggerService.clearLogs();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logs cleared successfully'),
            backgroundColor: PokerFriendColors.dark3,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing logs: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _seedTestData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Seed Test Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              '• 5 opponents (FISH, TAG, LAG, NIT, MANIAC)\n'
              '• 1 session with 50 hands\n'
              '• Various scenarios (opens, 3bets, 4bets, mistakes)',
              style: TextStyle(color: PokerFriendColors.dark9, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'Use this for testing Session Analytics.',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: PokerFriendColors.green,
            ),
            child: Text('Seed Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PokerFriendColors.dark2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: PokerFriendColors.green),
                  SizedBox(height: 16),
                  Text(
                    'Seeding test data...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );

        await TestDataSeedService.seedTestData(force: true);

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test data seeded successfully! Check History for the new session.'),
            backgroundColor: PokerFriendColors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error seeding test data: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _cleanupTestData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Cleanup Test Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will delete all test opponents (FISH Mike, TAG Sarah, etc.) and the test session with 50 hands.',
          style: TextStyle(color: PokerFriendColors.dark9),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: PokerFriendColors.red,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PokerFriendColors.dark2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: PokerFriendColors.red),
                  SizedBox(height: 16),
                  Text(
                    'Cleaning up test data...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );

        await TestDataSeedService.cleanupTestData();

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test data cleaned up successfully!'),
            backgroundColor: PokerFriendColors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cleaning up test data: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
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