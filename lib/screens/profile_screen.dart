import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding/onboarding_flow.dart';
import '../services/auth_service.dart';
import '../services/display_identity_service.dart';
import '../services/subscription_service.dart';
import '../services/username_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/logger_service.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import '../screens/settings_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/username_setup_screen.dart';
import '../screens/poker_hand_screen.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../widgets/session_summary_card.dart';
import '../services/firebase_service.dart';
import 'session_analytics_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  String? _username;
  bool _useNicknameInGame = false;
  bool _isAdmin = false;
  StreamSubscription<bool>? _premiumSub;

  @override
  void initState() {
    super.initState();
    LoggerService.logScreenView('profile');
    _loadData();
    _premiumSub = SubscriptionService.premiumStatusStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final username = await UsernameService.getUsername();
      final useNickname = await UsernameService.getUseNicknameInGame();

      // Check admin role — dev tools only in debug builds
      bool isAdmin = false;
      if (!kReleaseMode) {
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

  String _subscriptionPillLabel(AppLocalizations l10n) {
    switch (SubscriptionService.currentTier) {
      case 'club':  return l10n.profileTierClub;
      case 'elite': return l10n.profileTierElite;
      case 'pro':   return l10n.profileTierPro;
      default:      return l10n.profileUpgrade;
    }
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
                  _subscriptionPillLabel(l10n),
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
    final l10n = AppLocalizations.of(context);
    final tierOverride = SubscriptionService.debugTierOverride;
    final currentTierLabel = tierOverride != null
        ? l10n.profileTierOverrideSubtitleActive(tierOverride)
        : l10n.profileTierOverrideSubtitleReal(SubscriptionService.currentTier);

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
                l10n.profileDevTools,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileTierOverride,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      currentTierLabel,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8C8C8C),
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButton<String?>(
                value: tierOverride,
                dropdownColor: const Color(0xFF1C1F21),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: Colors.white,
                ),
                underline: const SizedBox.shrink(),
                onChanged: (value) async {
                  await SubscriptionService.setDebugTierOverride(value);
                  setState(() {});
                },
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Real — no override',
                      style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Color(0xFF8C8C8C)),
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'pro',
                    child: Text(
                      l10n.profileTierPro,
                      style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'elite',
                    child: Text(
                      l10n.profileTierElite,
                      style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'club',
                    child: Text(
                      l10n.profileTierClub,
                      style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              // Send a non-fatal error (delivered while app is running)
              await FirebaseCrashlytics.instance.recordError(
                Exception('Test non-fatal error from dev tools'),
                StackTrace.current,
                reason: 'Manual test from profile dev tools',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Non-fatal error sent to Crashlytics')),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Test Crashlytics (non-fatal error)',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              FirebaseCrashlytics.instance.crash();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Test Crashlytics (force crash)',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () => _launchQuickDebugSession(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B6B).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFF6B6B).withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Quick Debug Session (7P Cash 1/2)',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showTestSummaryCard(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B6B).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFF6B6B).withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Test Summary Card (Tournament)',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OnboardingFlow(
                    skipNickname: true,
                    testMode: true,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF6B9FFF).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF6B9FFF).withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Test Onboarding + Paywall',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B9FFF),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openLatestSession(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFFFFB74D).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFFB74D).withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  'Open Latest Session Analytics',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFB74D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestSummaryCard() {
    SessionSummaryCard.show(
      context: context,
      data: SessionSummaryData(
        sessionName: 'Deepstack Turbo',
        gameType: GameType.tournament,
        profitLoss: -600.0,
        totalBuyIn: 600.0,
        handsPlayed: 47,
        biggestPot: 95000,
        biggestPotBB: 1000,
        durationMinutes: 185,
        finishedPlace: 11,
        fieldSize: 28,
        prizeWon: 0,
        biggestPotWonCards: 'A\u2660 K\u2665',
        biggestPotLostCards: 'Hand #42',
      ),
    );
  }

  Future<void> _openLatestSession() async {
    try {
      final userId = AuthService.currentUser?.uid;
      if (userId == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('poker_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sessions found')),
          );
        }
        return;
      }
      final doc = snap.docs.first;
      final sessionData = doc.data();
      sessionData['id'] = doc.id;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionAnalyticsScreen(
            sessionData: sessionData,
            sessionId: doc.id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _launchQuickDebugSession() {
    final sessionManager = PokerSessionManager(
      smallBlind: 1,
      bigBlind: 2,
      playerCount: 9,
      gameType: GameType.cash,
      sessionName: 'Debug Session',
      initialBuyIn: 200,
      startingStack: 200,
    );

    // 7 players in seats 1-7, hero at seat 1
    const playerNames = ['Hero', 'Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank'];
    for (int i = 0; i < 7; i++) {
      final seat = i + 1;
      sessionManager.addPlayer(seat, playerNames[i]);
      sessionManager.setPlayerStack(seat, 200);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PokerHandScreen(
          smallBlind: 1,
          bigBlind: 2,
          numberOfPlayers: 9,
          gameType: GameType.cash,
          hasBBante: false,
          ante: 0,
          sessionName: 'Debug Session',
          buyInAmount: 200,
          startingStack: 200,
          initialSeat: 1,
          initialButtonPosition: 1,
          sessionManager: sessionManager,
        ),
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
