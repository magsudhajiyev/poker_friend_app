import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/bankroll_service.dart';
import '../services/display_identity_service.dart';
import '../services/session_result_service.dart';
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
  final _goalController = TextEditingController();
  final _bankrollController = TextEditingController();
  final _sessionResultController = TextEditingController();

  double currentBankroll = 0.0;
  double bankrollGoal = 0.0;
  bool isLoading = true;
  String _selectedGameType = 'tournament'; // Default to tournament as shown in Figma
  String? _username;
  bool _useNicknameInGame = false;

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
      final username = await UsernameService.getUsername();
      final useNickname = await UsernameService.getUseNicknameInGame();

      if (mounted) {
        setState(() {
          currentBankroll = bankroll;
          bankrollGoal = goal;
          _goalController.text = goal.toStringAsFixed(0);
          _bankrollController.text = bankroll.toStringAsFixed(0);
          _username = username;
          _useNicknameInGame = useNickname;
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
    final l10n = AppLocalizations.of(context);
    try {
      final newGoal = double.tryParse(_goalController.text) ?? 0.0;
      if (newGoal > 0) {
        await BankrollService.setBankrollGoal(newGoal);
        setState(() {
          bankrollGoal = newGoal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileGoalUpdatedSuccess),
            backgroundColor: Color(0xFF89F1EC),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileErrorUpdatingGoal),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateBankroll() async {
    final l10n = AppLocalizations.of(context);
    try {
      final newBankroll = double.tryParse(_bankrollController.text) ?? 0.0;
      if (newBankroll >= 0) {
        await BankrollService.setCurrentBankroll(newBankroll);
        setState(() {
          currentBankroll = newBankroll;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileBankrollUpdatedSuccess),
            backgroundColor: Color(0xFF89F1EC),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileErrorUpdatingBankroll),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addSessionResult() async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = double.tryParse(_sessionResultController.text) ?? 0.0;

      if (result == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profilePleaseEnterValidAmount),
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
          content: Text(l10n.profileSessionResultAdded),
          backgroundColor: Color(0xFF62E3BC),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileErrorAddingResult),
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

                // Cards
                _buildBankrollGoalCard(),
                SizedBox(height: 16),

                _buildCurrentBankrollCard(),
                SizedBox(height: 16),

                _buildSessionResultCard(),
                SizedBox(height: 16),

                // Dev tools — only visible to super admin
                if (_isDevUser) ...[
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

  Widget _buildBankrollGoalCard() {
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
          Text(
            l10n.profileBankrollGoal,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),

          // Input field
          _buildInputField(_goalController, '${bankrollGoal.toStringAsFixed(0)}'),
          SizedBox(height: 24),

          // Button
          _buildActionButton(l10n.profileUpdateGoal, _updateGoal),
        ],
      ),
    );
  }

  Widget _buildCurrentBankrollCard() {
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
          Text(
            l10n.profileCurrentBankroll,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),

          _buildInputField(_bankrollController, '${currentBankroll.toStringAsFixed(0)}'),
          SizedBox(height: 24),

          _buildActionButton(l10n.profileUpdateBankroll, _updateBankroll),
        ],
      ),
    );
  }

  Widget _buildSessionResultCard() {
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
          Text(
            l10n.profileAddSessionResult,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            l10n.profileSessionResultHint,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8C8C8C),
            ),
          ),
          SizedBox(height: 14),

          // Cash/Tournament toggle
          _buildGameTypeToggle(),
          SizedBox(height: 14),

          _buildInputField(_sessionResultController, '0'),
          SizedBox(height: 24),

          _buildActionButton(l10n.profileAddResult, _addSessionResult),
        ],
      ),
    );
  }

  Widget _buildGameTypeToggle() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Color(0xFF35373C),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          // Cash option
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedGameType = 'cash'),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: _selectedGameType == 'cash' ? Color(0xFF02050B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                  border: _selectedGameType == 'cash'
                      ? Border.all(color: Color(0xFF73D4CF), width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).profileCash,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _selectedGameType == 'cash' ? Colors.white : Color(0xFF8C8C8C),
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
                height: 38,
                decoration: BoxDecoration(
                  color: _selectedGameType == 'tournament' ? Color(0xFF02050B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(19),
                  border: _selectedGameType == 'tournament'
                      ? Border.all(color: Color(0xFF73D4CF), width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).profileTournament,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _selectedGameType == 'tournament' ? Colors.white : Color(0xFF8C8C8C),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color(0xFF4E5054),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
        style: GoogleFonts.ibmPlexSans(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 16, right: 4),
            child: Text(
              '\$',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8C8C8C),
              ),
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
          hintText: hint,
          hintStyle: GoogleFonts.ibmPlexSans(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8C8C8C),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          color: Color(0xFF89F1EC),
          borderRadius: BorderRadius.circular(110),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  // TODO: TEMPORARY — remove before release
  static const _devUserIds = <String>{
    // Add your Firebase UID here (check AuthService.userId at runtime)
  };

  bool get _isDevUser {
    final uid = AuthService.userId;
    // Show dev tools if UID is in the allowlist, OR if the list is empty (dev convenience)
    return uid != null && (_devUserIds.isEmpty || _devUserIds.contains(uid));
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
}
