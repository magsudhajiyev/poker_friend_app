import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/final_standings.dart';
import '../../services/event_service.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/decorations.dart';

/// Trophy variant drawn next to the top-3 ranks in the final standings list.
enum _TrophyKind { gold, silver, bronze }

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
  // Flip to false to hide the share-standings button entirely.
  static const bool _kShowShareButton = true;

  // Row backgrounds for ranks 1 and 2 — one-off Figma colors that don't
  // belong in the global palette.
  static const Color _kRank1Bg = Color(0xFF4A4E58);
  static const Color _kRank2Bg = Color(0xFF2F333A);

  FinalStandings? _standings;
  bool _isLoading = true;
  String? _error;

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

      if (!mounted) return;
      setState(() {
        _standings = standings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      backgroundColor: AppColors.bgPrimary,
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
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.errorRed,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.finalStandingsNoData,
                                style: AppTypography.ibm(
                                  color: AppColors.textDisabled,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.finalStandingsNoDataHint,
                                style: AppTypography.ibm(
                                  color: AppColors.textDisabled,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  )
                else if (_standings == null || _standings!.standings.isEmpty)
                  Expanded(
                    child: Center(
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_events_outlined,
                                size: 48,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.finalStandingsEmpty,
                                style: AppTypography.ibm(
                                  color: AppColors.textDisabled,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          );
                        },
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeaderIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.finalStandingsTitle,
                  style: AppTypography.ibm(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxs),
                Text(
                  widget.event.name,
                  style: AppTypography.ibm(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMint,
                    height: 1.47,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_kShowShareButton) ...[
            const SizedBox(width: AppSpacing.xxs),
            _buildHeaderIconButton(
              icon: Icons.emoji_events_outlined,
              onTap: _onSharePressed,
            ),
          ],
        ],
      ),
    );
  }

  /// Circular 44×44 icon button used in the header (back + share).
  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.neutral700,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// Shares the final standings as plain text via the native share sheet.
  void _onSharePressed() {
    final standings = _standings;
    if (standings == null || standings.standings.isEmpty) return;

    final lines = standings.standings
        .map((s) => '${s.finalRank}. ${s.playerName}')
        .join('\n');
    final text = '${widget.event.name} — Final Standings\n\n$lines';
    Share.share(text, subject: '${widget.event.name} — Final Standings');
  }

  Widget _buildStatsRow() {
    final standings = _standings!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return _buildStatTile(
                    value: '${standings.totalPlayers}',
                    label: l10n.finalStandingsPlayers,
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return _buildStatTile(
                    value: DateFormat('MMM d').format(standings.completedAt),
                    label: l10n.finalStandingsCompleted,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rounded 8px stat tile used in the header summary row.
  /// Matches Figma: #1B1E24 bg, mint-colored value on top, gray label below.
  Widget _buildStatTile({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral800,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTypography.listRowLabel(color: AppColors.buttonPrimary),
          ),
          const SizedBox(height: AppSpacing.xxxs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textDisabled,
              height: 1.44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsList() {
    final standings = _standings!.standings;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.bottomPadding,
      ),
      itemCount: standings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xxs),
      itemBuilder: (context, index) => _buildStandingRow(standings[index]),
    );
  }

  Widget _buildStandingRow(FinalPlayerStanding standing) {
    final style = _rowStyleForRank(standing.finalRank);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: style.bg,
        border: Border.all(color: AppColors.neutral700),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: Row(
        children: [
          // 32×32 rank square
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: style.rankBg,
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              '${standing.finalRank}',
              style: AppTypography.listRowLabel(color: style.rankColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              standing.playerName,
              style: AppTypography.listRowLabel(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (style.trophy != null) ...[
            const SizedBox(width: AppSpacing.xs),
            _buildTrophyBadge(style.trophy!),
          ],
        ],
      ),
    );
  }

  /// Resolves row-level styling (background, rank square, trophy) for a
  /// given final rank. Matches Figma node 1199:7597.
  _RowStyle _rowStyleForRank(int rank) {
    switch (rank) {
      case 1:
        return const (
          bg: _kRank1Bg,
          rankBg: AppColors.neutral800,
          rankColor: AppColors.buttonPrimary,
          trophy: _TrophyKind.gold,
        );
      case 2:
        return const (
          bg: _kRank2Bg,
          rankBg: AppColors.neutral800,
          rankColor: AppColors.mint500,
          trophy: _TrophyKind.silver,
        );
      case 3:
        return const (
          bg: AppColors.neutral800,
          rankBg: AppColors.bgSurface,
          rankColor: AppColors.mint700,
          trophy: _TrophyKind.bronze,
        );
      default:
        return const (
          bg: AppColors.bgSurface,
          rankBg: Colors.black,
          rankColor: Colors.white,
          trophy: null,
        );
    }
  }

  /// 40×40 trophy badge drawn next to top-3 rows.
  Widget _buildTrophyBadge(_TrophyKind kind) {
    switch (kind) {
      case _TrophyKind.gold:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5D522C), Color(0xFF453600)],
            ),
            border: Border.all(color: const Color(0xFF948A7A)),
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events,
            color: Color(0xFFFFD13F),
            size: 24,
          ),
        );
      case _TrophyKind.silver:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2A292E),
            border: Border.all(color: const Color(0xFF525252)),
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events,
            color: Color(0xFFC0C0C0),
            size: 24,
          ),
        );
      case _TrophyKind.bronze:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2D1F1A),
            border: Border.all(color: const Color(0xFF482407)),
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events,
            color: Color(0xFFCD7F32),
            size: 24,
          ),
        );
    }
  }
}

/// Resolved styling for a single standings row.
typedef _RowStyle = ({
  Color bg,
  Color rankBg,
  Color rankColor,
  _TrophyKind? trophy,
});
