import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/bankroll_service.dart';
import '../services/session_result_service.dart';
import '../screens/settings_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/intro_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _goalController = TextEditingController();
  final _bankrollController = TextEditingController();
  final _sessionResultController = TextEditingController();

  double currentBankroll = 0.0;
  double bankrollGoal = 0.0;
  bool isLoading = true;
  String _selectedGameType = 'tournament'; // Default to tournament as shown in Figma

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _bankrollController.dispose();
    _sessionResultController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bankroll = await BankrollService.getCurrentBankroll();
      final goal = await BankrollService.getBankrollGoal();

      if (mounted) {
        setState(() {
          currentBankroll = bankroll;
          bankrollGoal = goal;
          _goalController.text = goal.toStringAsFixed(0);
          _bankrollController.text = bankroll.toStringAsFixed(0);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateGoal() async {
    try {
      final newGoal = double.tryParse(_goalController.text) ?? 0.0;
      if (newGoal > 0) {
        await BankrollService.setBankrollGoal(newGoal);
        setState(() {
          bankrollGoal = newGoal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal updated successfully!'),
            backgroundColor: Color(0xFF62E3BC),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating goal'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateBankroll() async {
    try {
      final newBankroll = double.tryParse(_bankrollController.text) ?? 0.0;
      if (newBankroll >= 0) {
        await BankrollService.setCurrentBankroll(newBankroll);
        setState(() {
          currentBankroll = newBankroll;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bankroll updated successfully!'),
            backgroundColor: Color(0xFF62E3BC),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bankroll'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addSessionResult() async {
    try {
      final result = double.tryParse(_sessionResultController.text) ?? 0.0;

      if (result == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid amount'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await BankrollService.addToBankroll(result);
      await SessionResultService.addSessionResult(
        amount: result,
        gameType: _selectedGameType,
      );

      await _loadData();
      _sessionResultController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session result added!'),
          backgroundColor: Color(0xFF62E3BC),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding session result'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF62E3BC)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Elliptical teal glow at top
          Positioned(
            top: -162,
            left: (screenWidth - 412) / 2,
            child: Container(
              width: 412,
              height: 217,
              child: Transform.scale(
                scaleX: 1.5,
                scaleY: 0.7,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: [
                        const Color(0xFF2E5A59).withOpacity(0.8),
                        const Color(0xFF2E5A59).withOpacity(0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content container
          Positioned(
            top: 68,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(color: Color(0xFF262626), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2E5A59),
                    blurRadius: 64,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 21, 20, 100),
                child: Column(
                  children: [
                    // Header row
                    _buildHeaderRow(),
                    SizedBox(height: 36),

                    // Profile section
                    _buildProfileSection(),
                    SizedBox(height: 36),

                    // Cards
                    _buildBankrollGoalCard(),
                    SizedBox(height: 16),

                    _buildCurrentBankrollCard(),
                    SizedBox(height: 16),

                    _buildSessionResultCard(),
                    SizedBox(height: 16),

                    _buildSettingsCard(),
                    SizedBox(height: 36),

                    // Footer
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),

        // Upgrade button
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PaywallScreen()),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF104034).withOpacity(0.6),
              borderRadius: BorderRadius.circular(70),
              border: Border.all(color: Color(0xFF89F1EC), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF91FFFB).withOpacity(0.25),
                  blurRadius: 21,
                  offset: Offset(3, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.diamond_outlined,
                  color: Color(0xFF89F1EC),
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Upgrade',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF89F1EC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        // Avatar — Google photo or initials fallback
        _buildAvatar(56),
        SizedBox(height: 12),

        // Name
        Text(
          AuthService.userDisplayName,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),

        // Email
        Text(
          AuthService.currentUser?.email ?? '',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBankrollGoalCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bankroll Goal',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.43,
            ),
          ),
          SizedBox(height: 14),

          // Input field
          _buildInputField(_goalController, '\$ ${bankrollGoal.toStringAsFixed(0)}'),
          SizedBox(height: 24),

          // Button
          _buildActionButton('Update Goal', _updateGoal),
        ],
      ),
    );
  }

  Widget _buildCurrentBankrollCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Bankroll',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.43,
            ),
          ),
          SizedBox(height: 14),

          _buildInputField(_bankrollController, '\$ ${currentBankroll.toStringAsFixed(0)}'),
          SizedBox(height: 24),

          _buildActionButton('Update Bankroll', _updateBankroll),
        ],
      ),
    );
  }

  Widget _buildSessionResultCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Session Result',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.43,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Enter positive for wins, negative for losses',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 14),

          // Cash/Tournament toggle
          _buildGameTypeToggle(),
          SizedBox(height: 14),

          _buildInputField(_sessionResultController, '\$ 0'),
          SizedBox(height: 24),

          _buildActionButton('Add Result', _addSessionResult),
        ],
      ),
    );
  }

  Widget _buildGameTypeToggle() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(80),
        border: Border.all(color: Color(0xFF2C2C2E), width: 1),
      ),
      child: Row(
        children: [
          // Cash option
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedGameType = 'cash'),
              child: Container(
                margin: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: _selectedGameType == 'cash'
                      ? LinearGradient(
                          colors: [Color(0xFF1E3B49), Color(0xFF4A887E)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(60),
                  border: _selectedGameType == 'cash'
                      ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Cash',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tournament option
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedGameType = 'tournament'),
              child: Container(
                margin: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: _selectedGameType == 'tournament'
                      ? LinearGradient(
                          colors: [Color(0xFF1E3B49), Color(0xFF4A887E)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(60),
                  border: _selectedGameType == 'tournament'
                      ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Tournament',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF3C3C43).withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(0xFF89F1EC).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
        style: GoogleFonts.ibmPlexSans(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.ibmPlexSans(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: Color(0xFF62E3BC),
          borderRadius: BorderRadius.circular(110),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: -0.43,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          // Settings
          _buildMenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
          SizedBox(height: 24),

          // Log out
          _buildMenuItem(
            icon: Icons.logout,
            label: 'Log out',
            onTap: _showSignOutConfirmation,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Version 1.0',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Final Table',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Last login ${_getLastLoginText()}',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(double size) {
    final photoURL = AuthService.userPhotoURL;
    if (photoURL != null && photoURL.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: photoURL,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildInitialsAvatar(size),
          errorWidget: (context, url, error) => _buildInitialsAvatar(size),
        ),
      );
    }
    return _buildInitialsAvatar(size);
  }

  Widget _buildInitialsAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A5A30), Color(0xFF1A3A20)],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: GoogleFonts.ibmPlexSans(
            fontSize: size * 0.357,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF87ED81),
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    final name = AuthService.userDisplayName;
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getLastLoginText() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${now.day} ${months[now.month - 1]} ${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => IntroScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.ibmPlexSans(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
