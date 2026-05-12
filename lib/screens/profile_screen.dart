import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/display_identity_service.dart';
import '../services/subscription_service.dart';
import '../services/username_service.dart';
import '../screens/settings_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/username_setup_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  String? _username;
  bool _useNicknameInGame = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final username = await UsernameService.getUsername();
      final useNickname = await UsernameService.getUseNicknameInGame();

      // Check admin role from Firestore
      bool isAdmin = false;
      final uid = AuthService.userId;
      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          isAdmin = doc.data()?['role'] == 'admin';
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _username = username;
          _useNicknameInGame = useNickname;
          _isAdmin = isAdmin;
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF02050B),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF89F1EC)),
          ),
        ),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Color(0xFF02050B),
      bottomNavigationBar: const GlobalBottomNavBar(currentScreen: 'profile'),
      body: Stack(
        children: [
          // Elliptical cyan/teal glow at top (background decoration)
          Positioned(
            top: -250 + topPadding,
            left: -screenWidth * 0.25,
            right: -screenWidth * 0.25,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    const Color(0xFF1A4A48).withOpacity(0.9),
                    const Color(0xFF1A4A48).withOpacity(0.5),
                    const Color(0xFF0D2B2A).withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Main scrollable content — full screen, no overlay container
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 100),
            child: Column(
              children: [
                // Header row
                _buildHeaderRow(),
                SizedBox(height: 36),

                // Profile section
                _buildProfileSection(),
                SizedBox(height: 24),

                // Username card
                _buildUsernameCard(),
                SizedBox(height: 36),

                // Dev tools — only visible to admin role
                if (_isAdmin) ...[
                  _buildDevToolsCard(),
                  SizedBox(height: 16),
                ],

                _buildSettingsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(0xFF101115),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.arrow_back,
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
                  l10n.profileUpgrade,
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
    final showNickname = _useNicknameInGame && _username != null;
    return Column(
      children: [
        // Avatar — Google photo or initials fallback
        _buildAvatar(56),
        SizedBox(height: 12),

        // Primary name (nickname or real name)
        Text(
          showNickname ? '@$_username' : AuthService.userDisplayName,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),

        // Secondary name (real name when showing nickname)
        if (showNickname) ...[
          SizedBox(height: 4),
          Text(
            AuthService.userDisplayName,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8C8C8C),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: 8),

        // Email
        Text(
          AuthService.currentUser?.email ?? '',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8C8C8C),
            height: 1.64,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUsernameCard() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            l10n.profileUsername,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),

          // Current username display + action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Username or "Not set" label
              Expanded(
                child: Text(
                  _username != null ? '@$_username' : l10n.profileNotSet,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _username != null
                        ? Color(0xFF89F1EC)
                        : Color(0xFF8C8C8C),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 12),
              // Set / Change button
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UsernameSetupScreen(
                        isChanging: _username != null,
                        currentUsername: _username,
                      ),
                    ),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      _username = result;
                    });
                    DisplayIdentityService.clearCache();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Color(0xFF89F1EC).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _username != null ? l10n.profileChange : l10n.profileSetUsername,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF89F1EC),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Use nickname toggle (only show if username is set)
          if (_username != null) ...[
            SizedBox(height: 20),
            Container(
              height: 1,
              color: Color(0xFF1C1F21),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileUseNicknameInGames,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        l10n.profileUseNicknameDescription(_username!),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF8C8C8C),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Switch(
                  value: _useNicknameInGame,
                  onChanged: (value) async {
                    setState(() {
                      _useNicknameInGame = value;
                    });
                    await UsernameService.setUseNicknameInGame(value);
                    DisplayIdentityService.clearCache();
                  },
                  activeColor: Color(0xFF62E3BC),
                  inactiveThumbColor: Color(0xFF8C8C8C),
                  inactiveTrackColor: Color(0xFF35373C),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildDevToolsCard() {
    final override = SubscriptionService.debugPremiumOverride;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Color(0xFFFF6B6B).withAlpha(80), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFFFF6B6B), size: 20),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).profileDevTools,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).profilePremiumOverride,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    override == null
                        ? AppLocalizations.of(context).profileUsingRealStatus(SubscriptionService.isPremium ? AppLocalizations.of(context).profilePremium : AppLocalizations.of(context).profileFree)
                        : AppLocalizations.of(context).profileOverridden(override ? AppLocalizations.of(context).profilePremium : AppLocalizations.of(context).profileFree),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8C8C8C),
                    ),
                  ),
                ],
              ),
              Switch(
                value: SubscriptionService.isPremium,
                onChanged: (value) async {
                  await SubscriptionService.setDebugPremiumOverride(value);
                  setState(() {});
                },
                activeColor: Color(0xFF62E3BC),
                inactiveThumbColor: Color(0xFF8C8C8C),
                inactiveTrackColor: Color(0xFF35373C),
              ),
            ],
          ),
          if (override != null) ...[
            SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                await SubscriptionService.setDebugPremiumOverride(null);
                setState(() {});
              },
              child: Text(
                AppLocalizations.of(context).profileResetToReal,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF89F1EC),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF89F1EC),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildSettingsCard() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          // Settings
          _buildMenuItem(
            icon: Icons.settings_outlined,
            label: l10n.settingsTitle,
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
            label: l10n.profileLogOut,
            onTap: _showSignOutConfirmation,
          ),
          SizedBox(height: 16),

          // Delete account
          _buildMenuItem(
            icon: Icons.delete_forever,
            label: 'Delete Account',
            onTap: _showDeleteAccountConfirmation,
            color: const Color(0xFFFF6B6B),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? Colors.white.withOpacity(0.9);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Icon(icon, color: itemColor, size: 24),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.profileVersion,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          l10n.onboardingFinalTable,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          l10n.profileLastLogin(_getLastLoginText()),
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
    final l10n = AppLocalizations.of(context);
    final months = [l10n.monthJan, l10n.monthFeb, l10n.monthMar, l10n.monthApr, l10n.monthMay, l10n.monthJun, l10n.monthJul, l10n.monthAug, l10n.monthSep, l10n.monthOct, l10n.monthNov, l10n.monthDec];
    return '${now.day} ${months[now.month - 1]} ${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showSignOutConfirmation() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.profileSignOut,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          l10n.profileSignOutConfirmation,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
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
              l10n.profileSignOut,
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

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Account',
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFFFF6B6B),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will permanently delete your account and all associated data (sessions, hands, stats, opponents). This action cannot be undone.\n\nIf you have an active subscription, please cancel it first in your device settings.',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final uid = AuthService.userId;
    if (uid == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Delete user data from Firestore
      await firestore.collection('users').doc(uid).delete();
      await firestore.collection('user_stats').doc(uid).delete();

      // Delete session results
      final results = await firestore
          .collection('session_results')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in results.docs) {
        await doc.reference.delete();
      }

      // Delete opponents
      final opponents = await firestore
          .collection('opponents')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in opponents.docs) {
        await doc.reference.delete();
        // Also delete opponent stats
        await firestore.collection('opponent_stats').doc(doc.id).delete();
      }

      // Delete poker sessions (and their subcollections are orphaned but harmless)
      final sessions = await firestore
          .collection('poker_sessions')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in sessions.docs) {
        await doc.reference.delete();
      }

      // Delete Firebase Auth account
      await AuthService.deleteAccount();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => IntroScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }
}
