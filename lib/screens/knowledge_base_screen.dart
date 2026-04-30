import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../l10n/app_localizations.dart';

enum KnowledgeBaseSection { stats, clubs }

class KnowledgeBaseScreen extends StatelessWidget {
  final KnowledgeBaseSection section;

  const KnowledgeBaseScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                    section == KnowledgeBaseSection.stats
                        ? l10n.kbStatsTitle
                        : l10n.kbClubsTitle,
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
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: section == KnowledgeBaseSection.stats
                    ? _buildStatsContent(l10n)
                    : _buildClubsContent(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoText(l10n.kbStatsIntro),
        const SizedBox(height: 24),
        _buildStatItem(
          l10n.kbVpipName,
          l10n.kbVpipFullName,
          l10n.kbVpipDescription,
        ),
        _buildStatItem(
          l10n.kbPfrName,
          l10n.kbPfrFullName,
          l10n.kbPfrDescription,
        ),
        _buildStatItem(
          l10n.kbThreeBetName,
          l10n.kbThreeBetFullName,
          l10n.kbThreeBetDescription,
        ),
        _buildStatItem(
          l10n.kbFoldTo3BetName,
          l10n.kbFoldTo3BetFullName,
          l10n.kbFoldTo3BetDescription,
        ),
        _buildStatItem(
          l10n.kbCBetName,
          l10n.kbCBetFullName,
          l10n.kbCBetDescription,
        ),
        _buildStatItem(
          l10n.kbStealName,
          l10n.kbStealFullName,
          l10n.kbStealDescription,
        ),
        _buildStatItem(
          l10n.kbCheckRaiseName,
          l10n.kbCheckRaiseFullName,
          l10n.kbCheckRaiseDescription,
        ),
      ],
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

  Widget _buildStatItem(String name, String fullName, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C1F21)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF89F1EC).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  name,
                  style: GoogleFonts.robotoMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF89F1EC),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fullName,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
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
