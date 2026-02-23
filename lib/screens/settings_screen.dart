import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/poker_friend_theme.dart';
import '../services/club_seeder_service.dart';
import '../services/club_service.dart';
import '../services/club_request_service.dart';
import '../models/club_member.dart';
import 'admin/club_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool autoAdvanceStreets = false;
  bool _isAppAdmin = false;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAppAdminStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoAdvanceStreets = prefs.getBool('auto_advance_streets') ?? false;
    });
  }

  Future<void> _checkAppAdminStatus() async {
    final isAdmin = await ClubRequestService.isAppAdmin();
    if (isAdmin) {
      final count = await ClubRequestService.getPendingCount();
      setState(() {
        _isAppAdmin = true;
        _pendingRequestCount = count;
      });
    }
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

                // App Admin Section - Only visible for app admins
                if (_isAppAdmin) ...[
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
                                color: PokerFriendColors.yellow.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.admin_panel_settings,
                                color: PokerFriendColors.yellow,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'App Admin',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Manage club registration requests',
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
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ClubRequestsScreen(),
                              ),
                            );
                            // Refresh pending count when returning
                            _checkAppAdminStatus();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: PokerFriendColors.dark1,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: PokerFriendColors.dark5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business_center,
                                  color: PokerFriendColors.yellow,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Club Requests',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (_pendingRequestCount > 0) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: PokerFriendColors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_pendingRequestCount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                ],
                                Icon(
                                  Icons.chevron_right,
                                  color: PokerFriendColors.dark9,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],

                // Debug Section - Club Admin (for testing)
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
                              color: PokerFriendColors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: PokerFriendColors.purple,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Debug: Club Admin',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Test role promotion',
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
                      _buildAdminButton(
                        label: 'Become Admin of Gringster Room',
                        onTap: () => _promoteToAdmin('Gringster Room'),
                      ),
                      SizedBox(height: 8),
                      _buildAdminButton(
                        label: 'Become Admin of Poczekalia',
                        onTap: () => _promoteToAdmin('Poczekalia'),
                      ),
                      SizedBox(height: 8),
                      _buildAdminButton(
                        label: 'Become Admin of House of Cards',
                        onTap: () => _promoteToAdmin('House of Cards'),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Debug Section - Test Dealer Invitation
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
                              color: PokerFriendColors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_add,
                              color: PokerFriendColors.green,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test Dealer Invitation',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'For testing deep link flow',
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
                      _buildAdminButton(
                        label: 'Add jeyranisayevaa@gmail.com to Gringster Room',
                        onTap: _addTestDealer,
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

  Widget _buildAdminButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PokerFriendColors.dark5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.arrow_forward_ios,
              color: PokerFriendColors.purple,
              size: 14,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTestDealer() async {
    const testEmail = 'jeyranisayevaa@gmail.com';
    const clubName = 'Gringster Room';

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: PokerFriendColors.green),
      ),
    );

    try {
      // Find the user by email
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: testEmail)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('User with email $testEmail not found. Make sure they have signed up first.');
      }

      final userData = userSnapshot.docs.first;
      final userId = userData.id;
      final displayName = userData.data()['displayName'] ?? 'Jeku';

      // Find the Gringster Room club
      final clubs = await ClubService.getClubs();
      final club = clubs.firstWhere(
        (c) => c.name == clubName,
        orElse: () => throw Exception('Club "$clubName" not found'),
      );

      // Add user directly as dealer
      await ClubService.addMemberToClub(
        clubId: club.id,
        userId: userId,
        displayName: displayName,
        email: testEmail,
        role: ClubRole.dealer,
      );

      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$displayName is now a dealer in $clubName!'),
          backgroundColor: PokerFriendColors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: PokerFriendColors.red,
        ),
      );
    }
  }

  Future<void> _promoteToAdmin(String clubName) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: PokerFriendColors.purple),
      ),
    );

    try {
      final success = await ClubSeederService.promoteCurrentUserToAdmin(clubName);
      Navigator.pop(context); // Close loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now admin of $clubName!'),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to promote. Make sure you are a member of $clubName.'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: PokerFriendColors.red,
        ),
      );
    }
  }
}
