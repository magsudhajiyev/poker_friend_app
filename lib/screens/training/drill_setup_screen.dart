import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design_system/components/modals/confirm_dialog.dart';
import '../../models/drill_models.dart';
import '../../models/opponent.dart';
import '../../services/drill_lineup_store.dart';
import '../../services/drill_opponent_profiler.dart';
import '../../services/opponent_service.dart';
import '../../services/subscription_service.dart';
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
  static const _accent = Color(0xFF89F1EC);

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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D1F),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Save lineup',
            style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Tuesday home game',
            hintStyle: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.3)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: Text('Save',
                style: GoogleFonts.ibmPlexSans(
                    color: _accent, fontWeight: FontWeight.w600)),
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
    ConfirmDialog.show(
      context,
      title: 'Delete lineup',
      message: 'Remove "${lineup.name}" from your saved lineups?',
      confirmLabel: 'Delete',
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
      backgroundColor: const Color(0xFF131616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_lineups.isNotEmpty) ...[
                    _sectionLabel('SAVED LINEUPS'),
                    const SizedBox(height: 8),
                    _buildLineupRow(),
                    const SizedBox(height: 20),
                  ],
                  _sectionLabel('TABLE'),
                  const SizedBox(height: 8),
                  _buildCard(child: _buildTableConfig()),
                  const SizedBox(height: 20),
                  _sectionLabel('SEATS'),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a seat to assign an opponent or move yourself.',
                    style: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  _buildSeatTable(),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _saveLineup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Center(
                        child: Text('Save this lineup',
                            style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _startDrill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Center(
                        child: _starting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : Text('Start Drill',
                                style: GoogleFonts.ibmPlexSans(
                                    color: Colors.black,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Training Drills',
              style: GoogleFonts.ibmPlexSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: const Color(0xFF87ED81),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _buildLineupRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _lineups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final lineup = _lineups[i];
          return GestureDetector(
            onTap: () => _applyLineup(lineup),
            onLongPress: () => _deleteLineup(lineup),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: Text(
                  '${lineup.name} · ${lineup.playerCount}P',
                  style: GoogleFonts.ibmPlexSans(
                      color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Players',
            style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.6), fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int n = 2; n <= 9; n++)
              _chip('$n', _playerCount == n, () {
                setState(() {
                  _playerCount = n;
                  if (_heroSeat > n) _heroSeat = 1;
                  _picks.removeWhere((seat, _) => seat > n);
                });
              }),
          ],
        ),
        const SizedBox(height: 16),
        Text('Stack depth',
            style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.6), fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _stackOptions)
              _chip('${s.toInt()}BB', _stackBB == s,
                  () => setState(() => _stackBB = s)),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: selected ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSeatTable() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.46,
      child: PokerTableWidget(
        activeSeatMap: {for (int i = 1; i <= 9; i++) i: i <= _playerCount},
        showDealerButton: false,
        showLogo: false,
        seatWidthFraction: 1.02,
        seatHeightFraction: 0.86,
        seatBuilder: (seatNumber, isActive) =>
            isActive ? _buildTableSeat(seatNumber) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTableSeat(int seat) {
    final isHero = seat == _heroSeat;
    final pick = _picks[seat];
    final label = isHero ? 'You' : (pick?.name ?? 'Bot');
    final display =
        label.length > 8 ? '${label.substring(0, 7)}…' : label;
    return GestureDetector(
      onTap: () => _tapSeat(seat),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF161719),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: isHero
                    ? _accent
                    : pick != null
                        ? const Color(0xFFA3FF78)
                        : const Color(0xFF2C2C2E),
                width: isHero ? 2 : 1.5,
              ),
            ),
            child: Text(
              display,
              maxLines: 1,
              style: GoogleFonts.ibmPlexSans(
                color: isHero
                    ? _accent
                    : pick != null
                        ? Colors.white
                        : Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Seat $seat',
            style: GoogleFonts.robotoMono(
              color: Colors.white.withOpacity(0.35),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumGate() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center,
                        color: Color(0xFF89F1EC), size: 48),
                    const SizedBox(height: 20),
                    Text(
                      'Train against your real opponents',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Seat the players you actually face, drill preflop spots '
                      'against bots that play with their measured tendencies, '
                      'and get exploit-based feedback on every decision.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 15,
                          height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () async {
                        await PaywallScreen.show(context,
                            featureName: 'Training Drills');
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Text('Upgrade to Premium',
                            style: GoogleFonts.ibmPlexSans(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
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
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.ibmPlexSans(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search opponents',
                  hintStyle: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.3)),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                          color: Color(0xFF89F1EC)),
                      title: Text('This is me',
                          style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFF89F1EC),
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('Move your seat here',
                          style: GoogleFonts.ibmPlexSans(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13)),
                      onTap: () => Navigator.pop(
                          context, const _SeatPick('__hero__', 'You')),
                    ),
                  ListTile(
                    leading: Icon(Icons.smart_toy,
                        color: Colors.white.withOpacity(0.5)),
                    title: Text('Generic bot',
                        style:
                            GoogleFonts.ibmPlexSans(color: Colors.white)),
                    subtitle: Text('Balanced regular',
                        style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withOpacity(0.4),
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
                          style:
                              GoogleFonts.ibmPlexSans(color: Colors.white)),
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
