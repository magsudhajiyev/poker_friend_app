import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../design_system/constants/colors.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/final_standings.dart';
import '../../models/event_ranking.dart';
import '../../services/event_service.dart';

/// Screen to display final standings for a completed event
class FinalStandingsScreen extends StatefulWidget {
  final Club club;
  final ClubEvent event;

  const FinalStandingsScreen({
    Key? key,
    required this.club,
    required this.event,
  }) : super(key: key);

  @override
  State<FinalStandingsScreen> createState() => _FinalStandingsScreenState();
}

class _FinalStandingsScreenState extends State<FinalStandingsScreen> {
  FinalStandings? _standings;
  bool _isLoading = true;
  String? _error;
  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadFinalStandings();
  }

  Future<void> _loadFinalStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final standings = await EventService.getFinalStandings(
        widget.club.id,
        widget.event.id,
      );

      setState(() {
        _standings = standings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load standings: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.backgroundPaper,
      body: Stack(
        children: [
          // Teal glow at top
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
                    const Color(0xFF2E5A59).withOpacity(0.9),
                    const Color(0xFF2E5A59).withOpacity(0.5),
                    const Color(0xFF0D2B2A).withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.buttonPrimary,
                      ),
                    ),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.errorRed,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No standings available',
                            style: GoogleFonts.ibmPlexSans(
                              color: AppColors.textDisabled,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This event may not have recorded standings',
                            style: GoogleFonts.ibmPlexSans(
                              color: AppColors.textDisabled,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_standings == null || _standings!.standings.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No standings recorded',
                            style: GoogleFonts.ibmPlexSans(
                              color: AppColors.textDisabled,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _buildStatsRow(),
                  Expanded(child: _buildStandingsList()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.backgroundSurface,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Standings',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.event.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: AppColors.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final standings = _standings!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Players',
            '${standings.totalPlayers}',
            Icons.people_outline,
          ),
          _buildStatItem(
            'Completed',
            DateFormat('MMM d').format(standings.completedAt),
            Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.buttonPrimary),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }

  Widget _buildStandingsList() {
    final standings = _standings!.standings;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: standings.length,
      itemBuilder: (context, index) {
        final standing = standings[index];
        return _buildStandingRow(standing);
      },
    );
  }

  Widget _buildStandingRow(FinalPlayerStanding standing) {
    final isBusted = standing.finalStatus == PlayerRankingStatus.busted;
    final isTopThree = standing.finalRank <= 3;

    final rankColor = switch (standing.finalRank) {
      1 => const Color(0xFFFFD13F),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => isBusted ? const Color(0xFF4E5054) : null,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: isTopThree && !isBusted
            ? Border.all(color: rankColor!.withOpacity(0.4))
            : null,
      ),
      child: Row(
        children: [
          // Rank circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rankColor?.withOpacity(isTopThree && !isBusted ? 0.15 : 0.3) ??
                  const Color(0xFF1B1E24),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isTopThree && !isBusted
                ? Icon(
                    Icons.emoji_events,
                    color: rankColor,
                    size: 22,
                  )
                : Text(
                    '${standing.finalRank}',
                    style: GoogleFonts.ibmPlexSans(
                      color: rankColor ?? AppColors.textDisabled,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              standing.playerName,
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: isBusted
                    ? AppColors.textDisabled
                    : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

        ],
      ),
    );
  }
}
