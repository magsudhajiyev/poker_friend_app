import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../l10n/app_localizations.dart';

enum KnowledgeBaseSection { stats, clubs }

class KnowledgeBaseScreen extends StatelessWidget {
  final KnowledgeBaseSection section;

  const KnowledgeBaseScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          TopNavBar(
            title: section == KnowledgeBaseSection.stats
                ? l10n.kbStatsTitle
                : l10n.kbClubsTitle,
            onBack: () => Navigator.pop(context),
            backgroundColor: AppColors.bgPrimary,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: section == KnowledgeBaseSection.stats
                  ? _buildStatsContent(l10n)
                  : _buildClubsContent(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              color: Color(0xFF007AFF),
              size: 24,
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.kbStatsTitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 20 / 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.kbStatsIntro,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 22 / 15,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Stat cards
        _buildStatCard(l10n.kbVpipName, l10n.kbVpipFullName, l10n.kbVpipDescription),
        const SizedBox(height: 16),
        _buildStatCard(l10n.kbPfrName, l10n.kbPfrFullName, l10n.kbPfrDescription),
        const SizedBox(height: 16),
        _buildStatCard(l10n.kbThreeBetName, l10n.kbThreeBetFullName, l10n.kbThreeBetDescription),
        const SizedBox(height: 16),
        _buildStatCard(l10n.kbFoldTo3BetName, l10n.kbFoldTo3BetFullName, l10n.kbFoldTo3BetDescription),
        const SizedBox(height: 16),
        _buildStatCard(l10n.kbCBetName, l10n.kbCBetFullName, l10n.kbCBetDescription),
        const SizedBox(height: 16),
        _buildStatCard(l10n.kbStealName, l10n.kbStealFullName, l10n.kbStealDescription),
        const SizedBox(height: 16),
        _buildStatCard(l10n.kbCheckRaiseName, l10n.kbCheckRaiseFullName, l10n.kbCheckRaiseDescription),
      ],
    );
  }

  Widget _buildStatCard(String chipLabel, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark pill chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people,
                  color: AppColors.textSecondary,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  chipLabel,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 16 / 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 20 / 17,
            ),
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            description,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 22 / 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubsContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoText(l10n.kbClubsIntro),
        const SizedBox(height: 24),
        _buildFeatureItem(
          Icons.event_rounded,
          l10n.kbLiveEventsTitle,
          l10n.kbLiveEventsDescription,
        ),
        _buildFeatureItem(
          Icons.leaderboard_rounded,
          l10n.kbLiveRankingsTitle,
          l10n.kbLiveRankingsDescription,
        ),
        _buildFeatureItem(
          Icons.people_rounded,
          l10n.kbOpponentTrackingTitle,
          l10n.kbOpponentTrackingDescription,
        ),
        _buildFeatureItem(
          Icons.qr_code_scanner_rounded,
          l10n.kbQrSeatTitle,
          l10n.kbQrSeatDescription,
        ),
        _buildFeatureItem(
          Icons.record_voice_over_rounded,
          l10n.kbDealerLoggingTitle,
          l10n.kbDealerLoggingDescription,
        ),
        _buildFeatureItem(
          Icons.bar_chart_rounded,
          l10n.kbSessionStatsTitle,
          l10n.kbSessionStatsDescription,
        ),
      ],
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        color: const Color(0xFF8C8C8C),
        height: 1.5,
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C1F21)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF87ED81).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF87ED81), size: 20),
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
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: const Color(0xFF8C8C8C),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
