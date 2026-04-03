import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';

enum KnowledgeBaseSection { stats, clubs }

class KnowledgeBaseScreen extends StatelessWidget {
  final KnowledgeBaseSection section;

  const KnowledgeBaseScreen({super.key, required this.section});

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
                    section == KnowledgeBaseSection.stats
                        ? 'Your Stats'
                        : 'Clubs & Events',
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
                    ? _buildStatsContent()
                    : _buildClubsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoText(
          'Final Table tracks 7 core poker metrics to help you understand and improve your game.',
        ),
        const SizedBox(height: 24),
        _buildStatItem(
          'VPIP',
          'Voluntarily Put \$ In Pot',
          'How often you enter a pot voluntarily (excluding blind posts). A high VPIP means you play many hands; a low VPIP means you\'re selective.',
        ),
        _buildStatItem(
          'PFR',
          'Preflop Raise',
          'How often you raise before the flop. The gap between VPIP and PFR shows how often you limp or cold-call.',
        ),
        _buildStatItem(
          '3-Bet',
          'Three-Bet Percentage',
          'How often you re-raise an opponent\'s open raise preflop. A higher 3-bet% indicates an aggressive preflop style.',
        ),
        _buildStatItem(
          'Fold to 3-Bet',
          'Fold to Three-Bet',
          'How often you fold after raising and facing a 3-bet. If too high, opponents can exploit you by 3-betting light.',
        ),
        _buildStatItem(
          'C-Bet',
          'Continuation Bet',
          'How often you bet on the flop after being the last preflop aggressor. A standard play showing strength.',
        ),
        _buildStatItem(
          'Steal',
          'Blind Steal Attempt',
          'How often you open-raise from late position (CO, BTN, SB) when the pot is unopened, aiming to take the blinds.',
        ),
        _buildStatItem(
          'Check-Raise',
          'Flop Check-Raise',
          'How often you check then raise on the flop. A deceptive move that can trap aggressive opponents.',
        ),
      ],
    );
  }

  Widget _buildClubsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoText(
          'Clubs let you connect with your local poker room and track live games.',
        ),
        const SizedBox(height: 24),
        _buildFeatureItem(
          Icons.event_rounded,
          'Live Events',
          'Club managers create events with multiple tables. Join an event to be part of the live rankings.',
        ),
        _buildFeatureItem(
          Icons.leaderboard_rounded,
          'Live Rankings',
          'See where you stand in real-time during events. Rankings update after every hand.',
        ),
        _buildFeatureItem(
          Icons.people_rounded,
          'Opponent Tracking',
          'Players you face at the club are automatically tracked. Save opponents to build detailed profiles.',
        ),
        _buildFeatureItem(
          Icons.qr_code_scanner_rounded,
          'QR Seat Assignment',
          'Scan a QR code at your table to join the session instantly. Your hands are tracked automatically by the dealer.',
        ),
        _buildFeatureItem(
          Icons.record_voice_over_rounded,
          'Dealer-Assisted Logging',
          'Dealers use voice commands to log actions for the entire table. No manual input needed from players.',
        ),
        _buildFeatureItem(
          Icons.bar_chart_rounded,
          'Session Stats',
          'After each session, see your profit/loss and how your stats changed. Every hand is recorded.',
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
