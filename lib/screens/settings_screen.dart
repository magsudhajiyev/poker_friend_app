import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/app_toggle.dart';
import '../services/club_request_service.dart';
import '../onboarding/onboarding_prefs.dart';
import 'admin/club_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _devUserId = 'FELwuk4XbvdibPCx9NesqP5dRIn1';
  bool autoAdvanceStreets = false;
  bool _isAppAdmin = false;
  int _pendingRequestCount = 0;
  bool _onboardingEnabled = false;
  bool _isDevUser = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAppAdminStatus();
    _checkDevUser();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoAdvanceStreets = prefs.getBool('auto_advance_streets') ?? false;
    });
  }

  Future<void> _checkAppAdminStatus() async {
    try {
      final isAdmin = await ClubRequestService.isAppAdmin();
      if (isAdmin) {
        final count = await ClubRequestService.getPendingCount();
        if (mounted) {
          setState(() {
            _isAppAdmin = true;
            _pendingRequestCount = count;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _checkDevUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == _devUserId) {
      final seen = await OnboardingPrefs.hasSeenOnboarding();
      if (mounted) {
        setState(() {
          _isDevUser = true;
          _onboardingEnabled = !seen;
        });
      }
    }
  }

  Future<void> _toggleOnboarding(bool enabled) async {
    if (enabled) {
      await OnboardingPrefs.resetOnboarding();
    } else {
      await OnboardingPrefs.markOnboardingSeen();
    }
    setState(() {
      _onboardingEnabled = enabled;
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
      backgroundColor: AppColors.backgroundPaper,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Settings',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Flow section
                    _buildSectionHeader('GAME FLOW'),
                    const SizedBox(height: 12),
                    _buildSettingsCard(
                      children: [
                        _buildToggleRow(
                          icon: Icons.fast_forward_rounded,
                          iconColor: const Color(0xFF89F1EC),
                          title: 'Auto-Advance Streets',
                          subtitle: autoAdvanceStreets
                              ? 'Automatically moves to next street'
                              : 'Manual control over game progression',
                          value: autoAdvanceStreets,
                          onChanged: _saveAutoAdvanceStreets,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoBox(
                          autoAdvanceStreets
                              ? 'The game automatically moves from Preflop to Flop to Turn to River. Best for experienced players who want faster gameplay.'
                              : 'You have full control over when to advance to the next street. Ideal for learning and careful hand review.',
                        ),
                      ],
                    ),

                    // Onboarding Tour - Dev only
                    if (_isDevUser) ...[
                      const SizedBox(height: 28),
                      _buildSectionHeader('DEVELOPER'),
                      const SizedBox(height: 12),
                      _buildSettingsCard(
                        children: [
                          _buildToggleRow(
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF87ED81),
                            title: 'Onboarding Tour',
                            subtitle: _onboardingEnabled
                                ? 'Will show on next Home visit'
                                : 'Completed',
                            value: _onboardingEnabled,
                            onChanged: _toggleOnboarding,
                          ),
                        ],
                      ),
                    ],

                    // App Admin Section
                    if (_isAppAdmin) ...[
                      const SizedBox(height: 28),
                      _buildSectionHeader('ADMIN'),
                      const SizedBox(height: 12),
                      _buildSettingsCard(
                        children: [
                          _buildNavigationRow(
                            icon: Icons.business_center_rounded,
                            iconColor: const Color(0xFFE8B55A),
                            title: 'Club Requests',
                            subtitle: 'Manage registration requests',
                            badge: _pendingRequestCount > 0
                                ? _pendingRequestCount
                                : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ClubRequestsScreen(),
                                ),
                              );
                              _checkAppAdminStatus();
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF87ED81),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1C1F21),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: const Color(0xFF8C8C8C),
                ),
              ),
            ],
          ),
        ),
        AppToggle(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    int? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: const Color(0xFF8C8C8C),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD55A41),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF8C8C8C),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          color: const Color(0xFF8C8C8C),
          height: 1.5,
        ),
      ),
    );
  }
}
