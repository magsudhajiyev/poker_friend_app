import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/app_toggle.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../services/club_request_service.dart';
import '../services/support_request_service.dart';
import '../onboarding/onboarding_state.dart';
import 'admin/club_requests_screen.dart';
import 'admin/support_requests_screen.dart';
import 'admin/notification_tester_screen.dart';
import 'knowledge_base_screen.dart';
import 'logging_mode_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAppAdmin = false;
  int _pendingRequestCount = 0;
  int _pendingSupportCount = 0;
  bool _isGuidedTourExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkAppAdminStatus();
  }

  Future<void> _checkAppAdminStatus() async {
    try {
      final isAdmin = await ClubRequestService.isAppAdmin();
      if (isAdmin) {
        final count = await ClubRequestService.getPendingCount();
        final supportCount = await SupportRequestService.getPendingCount();
        if (mounted) {
          setState(() {
            _isAppAdmin = true;
            _pendingRequestCount = count;
            _pendingSupportCount = supportCount;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPaper,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                    // Knowledge Base section
                    _buildSectionHeader('KNOWLEDGE BASE'),
                    const SizedBox(height: 12),
                    _buildSettingsCard(
                      children: [
                        // Collapsible Guided Tour header
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isGuidedTourExpanded = !_isGuidedTourExpanded),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF87ED81).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.school_rounded, color: Color(0xFF87ED81), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Guided Tour',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Replay onboarding tours',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: _isGuidedTourExpanded ? 0.0 : -0.25,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 12, left: 16),
                            child: Column(
                              children: [
                                _buildNavigationRow(
                                  icon: Icons.style_rounded,
                                  iconColor: const Color(0xFF89F1EC),
                                  title: 'Full Logging Tour',
                                  subtitle: 'Complete session tracking flow',
                                  onTap: () {
                                    OnboardingState.startFromPhase(1, individualMode: false);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoggingModeSelectionScreen(),
                                      ),
                                    ).then((_) {
                                      if (OnboardingState.isReplay) {
                                        OnboardingState.completeReplay();
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildNavigationRow(
                                  icon: Icons.touch_app_rounded,
                                  iconColor: const Color(0xFF89F1EC),
                                  title: 'Individual Logging Tour',
                                  subtitle: 'Single hand tracking flow',
                                  onTap: () {
                                    OnboardingState.startFromPhase(1, individualMode: true);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoggingModeSelectionScreen(),
                                      ),
                                    ).then((_) {
                                      if (OnboardingState.isReplay) {
                                        OnboardingState.completeReplay();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _isGuidedTourExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                        const SizedBox(height: 16),
                        _buildNavigationRow(
                          icon: Icons.insights_rounded,
                          iconColor: const Color(0xFF89F1EC),
                          title: 'Understanding Your Stats',
                          subtitle: 'Learn what each metric means',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const KnowledgeBaseScreen(
                                  section: KnowledgeBaseSection.stats,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildNavigationRow(
                          icon: Icons.groups_rounded,
                          iconColor: const Color(0xFF89F1EC),
                          title: 'Clubs & Events',
                          subtitle: 'How club play works',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const KnowledgeBaseScreen(
                                  section: KnowledgeBaseSection.clubs,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

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
                          const SizedBox(height: 12),
                          _buildNavigationRow(
                            icon: Icons.support_agent_rounded,
                            iconColor: const Color(0xFFE8B55A),
                            title: 'Support Requests',
                            subtitle: 'Manage user support tickets',
                            badge: _pendingSupportCount > 0
                                ? _pendingSupportCount
                                : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SupportRequestsScreen(),
                                ),
                              );
                              _checkAppAdminStatus();
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildNavigationRow(
                            icon: Icons.notifications_active_rounded,
                            iconColor: const Color(0xFF89F1EC),
                            title: 'Notification Tester',
                            subtitle: 'Preview all notification designs',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationTesterScreen(),
                                ),
                              );
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
        ],
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
