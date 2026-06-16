import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/modals/confirm_dialog.dart';
import '../../models/drill_models.dart';
import '../../models/opponent.dart';
import '../../services/drill_lineup_store.dart';
import '../../services/drill_opponent_profiler.dart';
import '../../models/observed_range.dart';
import '../../services/opponent_range_service.dart';
import '../../services/opponent_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/drill/observed_range_grid.dart';
import '../../widgets/poker_table_widget.dart';
import '../paywall_screen.dart';
import 'drill_table_screen.dart';

/// Table setup for training drills: seat yourself, fill the other seats from
/// your saved opponents, pick a stack depth, and start drilling against bots
/// that play like the real lineup.
class DrillSetupScreen extends StatefulWidget {
  const DrillSetupScreen({super.key});

  @override
  State<DrillSetupScreen> createState() => _DrillSetupScreenState();
}

class _SeatPick {
  final String opponentId; // '' = generic bot
  final String name;
  const _SeatPick(this.opponentId, this.name);
}

class _DrillSetupScreenState extends State<DrillSetupScreen> {
  static const _stackOptions = [20.0, 40.0, 60.0, 100.0, 150.0];

  int _playerCount = 6;
  int _heroSeat = 1;
  double _stackBB = 100;
  final Map<int, _SeatPick> _picks = {}; // seat -> opponent pick
  List<Opponent> _opponents = [];
  List<DrillLineup> _lineups = [];
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Opponent> opponents = [];
    try {
      opponents = await OpponentService.getAllOpponents();
    } catch (_) {}
    final lineups = await DrillLineupStore.getLineups();
    if (!mounted) return;
    setState(() {
      _opponents = opponents;
      _lineups = lineups;
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────

  void _applyLineup(DrillLineup lineup) {
    setState(() {
      _playerCount = lineup.playerCount.clamp(2, 9).toInt();
      _heroSeat = lineup.heroSeat.clamp(1, _playerCount).toInt();
      _stackBB = lineup.stackBB;
      _picks.clear();
      lineup.seatOpponentIds.forEach((seat, oppId) {
        if (seat <= _playerCount && seat != _heroSeat) {
          _picks[seat] = _SeatPick(oppId, lineup.seatNames[seat] ?? 'Bot');
        }
      });
    });
  }

  Future<void> _saveLineup() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg)),
        title: Text(l10n.drillSaveLineup,
            style: AppTypography.titleBase()),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.ibmPlexSans(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: l10n.drillSaveLineupHint,
            hintStyle: GoogleFonts.ibmPlexSans(
                color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel,
                style: GoogleFonts.ibmPlexSans(
                    color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.commonSave,
                style: GoogleFonts.ibmPlexSans(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final lineup = DrillLineup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      playerCount: _playerCount,
      heroSeat: _heroSeat,
      stackBB: _stackBB,
      seatOpponentIds: {
        for (final e in _picks.entries)
          if (e.key <= _playerCount && e.key != _heroSeat)
            e.key: e.value.opponentId
      },
      seatNames: {
        for (final e in _picks.entries)
          if (e.key <= _playerCount && e.key != _heroSeat)
            e.key: e.value.name
      },
    );
    await DrillLineupStore.saveLineup(lineup);
    final lineups = await DrillLineupStore.getLineups();
    if (mounted) setState(() => _lineups = lineups);
  }

  void _deleteLineup(DrillLineup lineup) {
    final l10n = AppLocalizations.of(context);
    ConfirmDialog.show(
      context,
      title: l10n.drillDeleteLineup,
      message: l10n.drillDeleteLineupMessage(lineup.name),
      confirmLabel: l10n.commonDelete,
      onConfirm: () async {
        await DrillLineupStore.deleteLineup(lineup.id);
        final lineups = await DrillLineupStore.getLineups();
        if (mounted) setState(() => _lineups = lineups);
      },
    );
  }

  Future<void> _tapSeat(int seat) async {
    // Move yourself by tapping another seat and choosing "This is me"
    if (seat == _heroSeat) return;
    final pick = await showModalBottomSheet<_SeatPick?>(
      context: context,
      backgroundColor: AppColors.infoCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDecorations.radiusXl)),
      ),
      isScrollControlled: true,
      builder: (context) => _OpponentPickerSheet(
        opponents: _opponents,
        showHeroOption: seat != _heroSeat,
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      if (pick.opponentId == '__hero__') {
        _picks.remove(seat);
        _picks.remove(_heroSeat);
        _heroSeat = seat;
      } else if (pick.opponentId == '__clear__') {
        _picks.remove(seat);
      } else if (seat != _heroSeat) {
        _picks[seat] = pick;
      }
    });
  }

  Future<void> _startDrill() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final seats = <DrillSeat>[];
      for (int s = 1; s <= _playerCount; s++) {
        if (s == _heroSeat) {
          seats.add(DrillSeat(seatNumber: s, isHero: true));
          continue;
        }
        final pick = _picks[s];
        DrillVillainProfile profile;
        if (pick != null && pick.opponentId.isNotEmpty) {
          profile =
              await DrillOpponentProfiler.profileFor(pick.opponentId, pick.name);
        } else {
          profile = DrillVillainProfile.prior;
        }
        seats.add(DrillSeat(seatNumber: s, isHero: false, profile: profile));
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DrillTableScreen(seats: seats, stackBB: _stackBB),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!SubscriptionService.isPremium) return _buildPremiumGate();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                children: [
                  if (_lineups.isNotEmpty) ...[
                    _sectionLabel(l10n.drillSavedLineups),
                    const SizedBox(height: AppSpacing.xxs),
                    _buildLineupRow(),
                    const SizedBox(height: AppSpacing.space5),
                  ],
                  _sectionLabel(l10n.drillTable),
                  const SizedBox(height: AppSpacing.xxs),
                  _buildCard(child: _buildTableConfig()),
                  const SizedBox(height: AppSpacing.space5),
                  _sectionLabel(l10n.drillSeats),
                  const SizedBox(height: AppSpacing.xxxs),
                  Text(
                    l10n.drillSeatsInstruction,
                    style: GoogleFonts.ibmPlexSans(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.xxxs),
                  _buildSeatTable(),
                  _buildScoutingRow(),
                  const SizedBox(height: AppSpacing.xxs),
                  AppButton(
                    label: l10n.drillSaveThisLineup,
                    variant: AppButtonVariant.secondaryLarge,
                    fullWidth: true,
                    onTap: _saveLineup,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _starting
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentPrimary),
                          ),
                        )
                      : AppButton(
                          label: l10n.drillStartDrill,
                          variant: AppButtonVariant.primaryLarge,
                          fullWidth: true,
                          onTap: _startDrill,
                        ),
                  const SizedBox(height: AppSpacing.space10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.whiteOverlay(opacity: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.drillTitle,
              style: GoogleFonts.ibmPlexSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: AppTypography.sectionHeader());
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoCardBg,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: child,
    );
  }

  Widget _buildLineupRow() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _lineups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _lineupCard(_lineups[i]),
      ),
    );
  }

  Widget _lineupCard(DrillLineup lineup) {
    return GestureDetector(
      onTap: () => _applyLineup(lineup),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay(opacity: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.whiteBorder()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups,
                  color: AppColors.accentPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lineup.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lineup.playerCount}P · ${lineup.stackBB.toInt()}BB',
                  style: GoogleFonts.robotoMono(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteLineup(lineup),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 16, color: AppColors.contentInactive),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableConfig() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(l10n.drillPlayers),
        const SizedBox(height: 8),
        _segmented([
          for (int n = 2; n <= 9; n++)
            (
              '$n',
              _playerCount == n,
              () {
                setState(() {
                  _playerCount = n;
                  if (_heroSeat > n) _heroSeat = 1;
                  _picks.removeWhere((seat, _) => seat > n);
                });
              }
            ),
        ]),
        const SizedBox(height: 18),
        _fieldLabel(l10n.drillStackDepth),
        const SizedBox(height: 8),
        _segmented([
          for (final s in _stackOptions)
            ('${s.toInt()}BB', _stackBB == s, () => setState(() => _stackBB = s)),
        ]),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSans(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500),
    );
  }

  /// Equal-width segmented selector — a clean alternative to wrapped chips
  /// for a contiguous set of options (player count, stack depth).
  Widget _segmented(List<(String, bool, VoidCallback)> items) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay(opacity: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _segButton(items[i].$1, items[i].$2, items[i].$3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: GoogleFonts.ibmPlexSans(
                color: selected
                    ? AppColors.textInverse
                    : AppColors.contentActive.withOpacity(0.8),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tappable chips for each assigned opponent → opens their scouting report
  /// (observed showdown range). Lets you validate how much real data exists
  /// before relying on it.
  Widget _buildScoutingRow() {
    final assigned = <String, String>{}; // id -> name
    for (final pick in _picks.values) {
      if (pick.opponentId.isNotEmpty) assigned[pick.opponentId] = pick.name;
    }
    if (assigned.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).drillScouting,
              style: AppTypography.sectionHeader()),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final e in assigned.entries)
                GestureDetector(
                  onTap: () => _showScouting(e.key, e.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: AppColors.whiteOverlay(opacity: 0.08),
                      borderRadius: BorderRadius.circular(
                          AppDecorations.pillRadius),
                      border: Border.all(
                          color: AppColors.whiteBorder()),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.query_stats,
                            size: 14, color: AppColors.accentPrimary),
                        const SizedBox(width: 6),
                        Text(e.value,
                            style: AppTypography.bodySmMedium(
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showScouting(String opponentId, String name) async {
    // Lightweight loading dialog while the showdown scan runs
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentPrimary),
      ),
    );
    ObservedRange range;
    try {
      range = await OpponentRangeService.forOpponent(opponentId, name);
    } catch (_) {
      range = ObservedRange.empty;
    }
    if (!mounted) return;
    Navigator.pop(context); // dismiss loader
    await ObservedRangeSheet.show(context, range);
  }

  Widget _buildSeatTable() {
    final screen = MediaQuery.of(context).size;
    // Break out of the ListView's horizontal padding so the table is
    // perfectly centered on screen.
    return SizedBox(
      width: screen.width,
      height: screen.height * 0.50,
      child: OverflowBox(
        maxWidth: screen.width,
        alignment: Alignment.center,
        child: SizedBox(
          width: screen.width,
          height: screen.height * 0.50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dotted background — same as session setup
              Image.asset(
                'assets/icons/Table bg_small.png',
                fit: BoxFit.cover,
              ),
              // Table + seats — same fractions as session setup
              PokerTableWidget(
                activeSeatMap: {
                  for (int i = 1; i <= 9; i++) i: i <= _playerCount,
                },
                showDealerButton: false,
                showLogo: true,
                tableWidthFraction: 0.68,
                tableHeightFraction: 0.72,
                seatWidthFraction: 0.68,
                seatHeightFraction: 0.72,
                seatAngleOffset: 7 * (2 * math.pi / 9),
                seatBuilder: (seatNumber, isActive) => isActive
                    ? _buildTableSeat(seatNumber)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableSeat(int seat) {
    final l10n = AppLocalizations.of(context);
    final isHero = seat == _heroSeat;
    final pick = _picks[seat];
    final label = isHero ? l10n.drillYou : (pick?.name ?? 'Bot');
    final display =
        label.length > 8 ? '${label.substring(0, 7)}…' : label;
    final borderColor = (isHero || pick != null)
        ? AppColors.accentSecondary
        : AppColors.bgElevated;
    return GestureDetector(
      onTap: () => _tapSeat(seat),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Text(
              display,
              maxLines: 1,
              style: GoogleFonts.ibmPlexSans(
                color: (isHero || pick != null)
                    ? AppColors.accentSecondary
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.drillSeatNumber(seat),
            style: GoogleFonts.robotoMono(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumGate() {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center,
                        color: AppColors.accentPrimary, size: 48),
                    const SizedBox(height: AppSpacing.space5),
                    Text(
                      l10n.drillPremiumTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.drillPremiumDescription,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      label: l10n.drillUpgradeToPremium,
                      variant: AppButtonVariant.white,
                      onTap: () async {
                        await PaywallScreen.show(context,
                            featureName: 'Training Drills');
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpponentPickerSheet extends StatefulWidget {
  final List<Opponent> opponents;
  final bool showHeroOption;
  const _OpponentPickerSheet({
    required this.opponents,
    this.showHeroOption = false,
  });

  @override
  State<_OpponentPickerSheet> createState() => _OpponentPickerSheetState();
}

class _OpponentPickerSheetState extends State<_OpponentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = widget.opponents
        .where((o) => o.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.whiteOverlay(opacity: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.ibmPlexSans(
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.drillSearchOpponents,
                  hintStyle: GoogleFonts.ibmPlexSans(
                      color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.whiteOverlay(opacity: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (widget.showHeroOption)
                    ListTile(
                      leading: const Icon(Icons.person,
                          color: AppColors.accentPrimary),
                      title: Text(l10n.drillThisIsMe,
                          style: GoogleFonts.ibmPlexSans(
                              color: AppColors.accentPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.drillMoveYourSeatHere,
                          style: GoogleFonts.ibmPlexSans(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      onTap: () => Navigator.pop(
                          context, const _SeatPick('__hero__', 'You')),
                    ),
                  ListTile(
                    leading: Icon(Icons.smart_toy,
                        color: AppColors.textSecondary),
                    title: Text(l10n.drillGenericBot,
                        style: GoogleFonts.ibmPlexSans(
                            color: AppColors.textPrimary)),
                    subtitle: Text(l10n.drillBalancedRegular,
                        style: GoogleFonts.ibmPlexSans(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                    onTap: () => Navigator.pop(
                        context, const _SeatPick('__clear__', 'Bot')),
                  ),
                  for (final o in filtered)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            o.color.flutterColor.withOpacity(0.25),
                        child: Text(
                          o.name.isNotEmpty ? o.name[0].toUpperCase() : '?',
                          style: GoogleFonts.ibmPlexSans(
                              color: o.color.flutterColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(o.name,
                          style: GoogleFonts.ibmPlexSans(
                              color: AppColors.textPrimary)),
                      onTap: () =>
                          Navigator.pop(context, _SeatPick(o.id, o.name)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
