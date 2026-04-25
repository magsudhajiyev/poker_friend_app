import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poker_game_state.dart';
import '../models/hand_state_machine.dart';
import '../models/stack_bucket.dart';
import '../models/opponent.dart';
import '../services/opponent_service.dart';
import '../utils/poker_positions.dart';
import 'stack_range_circle.dart';

class TableManagementSheet extends StatefulWidget {
  final PokerGameState gameState;
  final PokerSessionManager sessionManager;
  final int heroSeat;
  final VoidCallback onChanged;

  const TableManagementSheet({
    super.key,
    required this.gameState,
    required this.sessionManager,
    required this.heroSeat,
    required this.onChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required PokerGameState gameState,
    required PokerSessionManager sessionManager,
    required int heroSeat,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TableManagementSheet(
        gameState: gameState,
        sessionManager: sessionManager,
        heroSeat: heroSeat,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<TableManagementSheet> createState() => _TableManagementSheetState();
}

class _TableManagementSheetState extends State<TableManagementSheet> {
  int get _heroSeat => widget.sessionManager.ourSeatNumber ?? widget.heroSeat;

  @override
  Widget build(BuildContext context) {
    final btnPos = widget.gameState.buttonPosition;
    final activeSeats = widget.sessionManager.activeSeats.toList()..sort();

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {}, // Absorb taps on the sheet itself
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'TABLE',
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF87ED81),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.gameState.getActivePlayers().length} players',
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF8C8C8C),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Button position selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Dealer Button',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // BTN seat chips — only active seats
                    SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: activeSeats.map((seat) {
                          final isBTN = seat == btnPos;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: GestureDetector(
                              onTap: () {
                                widget.gameState.buttonPosition = seat;
                                widget.onChanged();
                                setState(() {});
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isBTN
                                      ? const Color(0xFF62E3BC).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                  border: isBTN
                                      ? Border.all(color: const Color(0xFF62E3BC), width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '$seat',
                                    style: GoogleFonts.ibmPlexSans(
                                      color: isBTN ? const Color(0xFF62E3BC) : const Color(0xFF8C8C8C),
                                      fontSize: 12,
                                      fontWeight: isBTN ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1C1F21), height: 1),
              // Seat list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.gameState.numberOfPlayers,
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xFF1C1F21),
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final seat = index + 1;
                    final isActive = widget.sessionManager.activeSeats.contains(seat);
                    final isHero = seat == _heroSeat;

                    if (!isActive) {
                      return _buildEmptySeat(seat);
                    }
                    return _buildActiveSeat(seat, isHero);
                  },
                ),
              ),
            ],
          ),
        ),
        );
        },
      ),
    );
  }

  Widget _buildEmptySeat(int seat) {
    return InkWell(
      onTap: () => _showAddPlayerDialog(seat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$seat',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF8C8C8C),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Add Player',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF62E3BC),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.add_circle_outline, color: Color(0xFF62E3BC), size: 20),
          ],
        ),
      ),
    );
  }

  String _getPositionForSeat(int seat) {
    final btnPos = widget.gameState.buttonPosition;
    final activeSeatsList = widget.sessionManager.activeSeats.toList()..sort();
    final activeCount = activeSeatsList.length;

    if (seat == widget.sessionManager.actualBBSeat) return 'BB';
    if (seat == widget.sessionManager.actualSBSeat) return 'SB';
    if (seat == btnPos) return 'BTN';

    if (activeCount <= 3) return '';

    // Calculate position relative to button using active players
    return PokerPositions.getPositionNameForActivePlayers(seat, btnPos, activeSeatsList);
  }

  Widget _buildActiveSeat(int seat, bool isHero) {
    final player = widget.gameState.players[seat - 1];
    final name = widget.sessionManager.playerNames[seat] ?? 'Seat $seat';
    final stack = player.currentStack;
    final confidence = player.stackConfidence;
    final bigBlind = widget.sessionManager.bigBlind;
    final position = _getPositionForSeat(seat);

    final stackDisplay = StackBucketHelper.displayForPlayer(
      stack: stack,
      bigBlind: bigBlind,
      isHero: isHero,
      formatCurrency: widget.gameState.formatCurrency,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Seat number circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isHero
                  ? const Color(0xFF62E3BC).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$seat',
                style: GoogleFonts.ibmPlexSans(
                  color: isHero ? const Color(0xFF62E3BC) : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + stack
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isHero ? '$name (You)' : name,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (position.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: position == 'BTN'
                              ? const Color(0xFF62E3BC).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          position,
                          style: GoogleFonts.ibmPlexSans(
                            color: position == 'BTN'
                                ? const Color(0xFF62E3BC)
                                : const Color(0xFF8C8C8C),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (!isHero)
                  StackRangeCircle(
                    currentStack: stack,
                    bigBlind: bigBlind,
                    confidence: confidence,
                    isHero: false,
                    isInteractive: widget.gameState.currentRound == BettingRound.preflop,
                    formatCurrency: widget.gameState.formatCurrency,
                    onRangeSelected: (StackRange range) {
                      final newStack = StackBucketHelper.midpointBB(range) * bigBlind;
                      widget.gameState.setPlayerStack(seat, newStack);
                      widget.gameState.players[seat - 1].stackConfidence = StackConfidence.medium;
                      widget.gameState.players[seat - 1].handsSinceLastObservation = 0;
                      widget.sessionManager.playerStacks[seat] = newStack;
                      widget.onChanged();
                      setState(() {});
                    },
                  )
                else
                  Text(
                    stackDisplay,
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF8C8C8C),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          // Action buttons
          if (!isHero) ...[
            _buildActionButton(
              icon: Icons.tune,
              tooltip: 'Adjust Stack',
              onTap: () => _showAdjustStackDialog(seat, stack),
            ),
            const SizedBox(width: 4),
            _buildActionButton(
              icon: Icons.add_shopping_cart,
              tooltip: 'Rebuy',
              onTap: () => _showRebuyDialog(seat, stack),
            ),
            const SizedBox(width: 4),
            _buildActionButton(
              icon: Icons.logout,
              tooltip: 'Remove',
              onTap: () => _removePlayer(seat),
              color: const Color(0xFFE36262),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = const Color(0xFF8C8C8C),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  void _showAddPlayerDialog(int seat) {
    final defaultStack = widget.sessionManager.bigBlind > 0
        ? (widget.sessionManager.bigBlind * 100).toDouble()
        : 0.0;
    final heroName = widget.sessionManager.playerNames[_heroSeat] ?? '';

    // Build a map of name→seat for currently seated players
    final seatedPlayers = <String, int>{};
    for (final entry in widget.sessionManager.playerNames.entries) {
      if (widget.sessionManager.activeSeats.contains(entry.key)) {
        seatedPlayers[entry.value.toLowerCase()] = entry.key;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlayerSheet(
        seat: seat,
        defaultStack: defaultStack,
        heroName: heroName,
        seatedPlayers: seatedPlayers,
        onAdd: (String name, double stack, bool isMe) {
          if (isMe) {
            // Move hero from old seat to this seat
            final oldHeroSeat = _heroSeat;
            final heroStack = widget.gameState.getPlayerStack(oldHeroSeat);

            // Clear old hero seat
            widget.sessionManager.activeSeats.remove(oldHeroSeat);
            widget.sessionManager.playerNames.remove(oldHeroSeat);
            widget.sessionManager.playerStacks.remove(oldHeroSeat);
            widget.gameState.setPlayerActive(oldHeroSeat, false);

            // Set new hero seat
            widget.sessionManager.ourSeatNumber = seat;
            widget.sessionManager.playerNames[seat] = heroName.isNotEmpty ? heroName : name;
            widget.sessionManager.playerStacks[seat] = heroStack > 0 ? heroStack : stack;
            widget.sessionManager.activeSeats.add(seat);
            widget.gameState.setPlayerActive(seat, true);
            widget.gameState.setPlayerStack(seat, heroStack > 0 ? heroStack : stack);
          } else {
            // Check if this player is already seated elsewhere — reseat them
            final existingSeat = seatedPlayers[name.toLowerCase()];
            if (existingSeat != null && existingSeat != seat) {
              widget.sessionManager.activeSeats.remove(existingSeat);
              widget.sessionManager.playerNames.remove(existingSeat);
              widget.sessionManager.playerStacks.remove(existingSeat);
              widget.sessionManager.playerIds.remove(existingSeat);
              widget.gameState.setPlayerActive(existingSeat, false);
            }

            widget.sessionManager.playerNames[seat] = name;
            widget.sessionManager.playerStacks[seat] = stack;
            widget.sessionManager.activeSeats.add(seat);
            widget.gameState.setPlayerActive(seat, true);
            widget.gameState.setPlayerStack(seat, stack);
          }
          widget.onChanged();
          setState(() {});
        },
      ),
    );
  }

  void _showAdjustStackDialog(int seat, double currentStack) {
    final controller = TextEditingController(text: currentStack.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          'Adjust Stack',
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Enter stack amount',
            hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF62E3BC)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF62E3BC), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C))),
          ),
          TextButton(
            onPressed: () {
              final newStack = double.tryParse(controller.text);
              if (newStack != null && newStack >= 0) {
                widget.gameState.setPlayerStack(seat, newStack);
                widget.sessionManager.playerStacks[seat] = newStack;
                widget.onChanged();
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: Text('Update', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF62E3BC))),
          ),
        ],
      ),
    );
  }

  void _showRebuyDialog(int seat, double currentStack) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          'Rebuy',
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Rebuy amount to add',
            hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF62E3BC)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF62E3BC), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C))),
          ),
          TextButton(
            onPressed: () {
              final rebuyAmount = double.tryParse(controller.text);
              if (rebuyAmount != null && rebuyAmount > 0) {
                final newStack = currentStack + rebuyAmount;
                widget.gameState.setPlayerStack(seat, newStack);
                widget.sessionManager.playerStacks[seat] = newStack;
                widget.onChanged();
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF62E3BC))),
          ),
        ],
      ),
    );
  }

  void _removePlayer(int seat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          'Remove Player?',
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Remove ${widget.sessionManager.playerNames[seat] ?? "Seat $seat"} from the table?',
          style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C))),
          ),
          TextButton(
            onPressed: () {
              widget.sessionManager.activeSeats.remove(seat);
              widget.gameState.setPlayerActive(seat, false);
              widget.onChanged();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: Text('Remove', style: GoogleFonts.ibmPlexSans(color: const Color(0xFFE36262))),
          ),
        ],
      ),
    );
  }
}

class _AddPlayerSheet extends StatefulWidget {
  final int seat;
  final double defaultStack;
  final String heroName;
  final Map<String, int> seatedPlayers; // lowercase name → seat
  final void Function(String name, double stack, bool isMe) onAdd;

  const _AddPlayerSheet({
    required this.seat,
    required this.defaultStack,
    required this.onAdd,
    this.heroName = '',
    this.seatedPlayers = const {},
  });

  @override
  State<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<_AddPlayerSheet> {
  late TextEditingController _nameController;
  late TextEditingController _stackController;
  final FocusNode _stackFocus = FocusNode();
  List<Opponent> _allOpponents = [];
  List<Opponent> _filteredOpponents = [];
  bool _showSaveAsOpponent = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _stackController = TextEditingController(
      text: widget.defaultStack > 0 ? widget.defaultStack.toStringAsFixed(0) : '',
    );
    _loadOpponents();
    _nameController.addListener(_onNameChanged);
  }

  Future<void> _loadOpponents() async {
    try {
      final opponents = await OpponentService.getAllOpponents();
      if (mounted) {
        setState(() => _allOpponents = opponents);
      }
    } catch (_) {}
  }

  void _onNameChanged() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredOpponents = [];
        _showSaveAsOpponent = false;
      });
      return;
    }
    final matches = _allOpponents
        .where((o) => o.name.toLowerCase().contains(query))
        .take(5)
        .toList();
    final exactMatch = _allOpponents.any((o) => o.name.toLowerCase() == query);
    setState(() {
      _filteredOpponents = matches;
      _showSaveAsOpponent = !exactMatch && query.length >= 2;
    });
  }

  void _selectOpponent(Opponent opponent) {
    _nameController.removeListener(_onNameChanged);
    _nameController.text = opponent.name;
    _nameController.addListener(_onNameChanged);
    setState(() {
      _filteredOpponents = [];
      _showSaveAsOpponent = false;
    });
    _stackFocus.requestFocus();
  }

  Future<void> _saveAsNewOpponent() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final newOpponent = OpponentService.createNewOpponent(name: name);
      await OpponentService.saveOpponent(newOpponent);
      _allOpponents.add(newOpponent);
      setState(() {
        _showSaveAsOpponent = false;
        _filteredOpponents = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name saved as opponent'),
            backgroundColor: const Color(0xFF1A1A1E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _submit() {
    final name = _nameController.text.trim();
    final stack = double.tryParse(_stackController.text) ?? widget.defaultStack;
    if (_isMe) {
      widget.onAdd(name, stack, true);
    } else if (name.isNotEmpty && stack > 0) {
      widget.onAdd(name, stack, false);
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _stackController.dispose();
    _stackFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Add Player — Seat ${widget.seat}',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1C1F21), height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "This is me" toggle
                    GestureDetector(
                      onTap: () => setState(() => _isMe = !_isMe),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isMe
                              ? const Color(0xFF62E3BC).withValues(alpha: 0.15)
                              : const Color(0xFF101115),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isMe
                                ? const Color(0xFF62E3BC)
                                : const Color(0xFF35373C),
                            width: _isMe ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isMe ? Icons.person : Icons.person_outline,
                              color: _isMe
                                  ? const Color(0xFF62E3BC)
                                  : const Color(0xFF8C8C8C),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This is me',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                color: _isMe
                                    ? const Color(0xFF62E3BC)
                                    : const Color(0xFF8C8C8C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Name field (hidden when "This is me")
                    if (!_isMe) ...[
                    Text(
                      'Name',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: const Color(0xFF8C8C8C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Search or enter name',
                        hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
                        filled: true,
                        fillColor: const Color(0xFF101115),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF35373C)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF35373C)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF62E3BC)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    // Opponent search results + save as opponent
                    if (_filteredOpponents.isNotEmpty || _showSaveAsOpponent)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101115),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF35373C)),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(6),
                          shrinkWrap: true,
                          children: [
                            ..._filteredOpponents.map((opponent) {
                              final seatedAt = widget.seatedPlayers[opponent.name.toLowerCase()];
                              return GestureDetector(
                                onTap: () => _selectOpponent(opponent),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF89F1EC),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        opponent.name,
                                        style: GoogleFonts.ibmPlexSans(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (seatedAt != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Seat $seatedAt',
                                            style: GoogleFonts.ibmPlexSans(
                                              color: const Color(0xFF8C8C8C),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                            if (_showSaveAsOpponent)
                              GestureDetector(
                                onTap: _saveAsNewOpponent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_add_outlined,
                                        color: Color(0xFF62E3BC),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Save "${_nameController.text.trim()}" as opponent',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: const Color(0xFF62E3BC),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Stack field
                    Text(
                      'Starting Stack',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: const Color(0xFF8C8C8C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _stackController,
                      focusNode: _stackFocus,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: widget.defaultStack > 0 ? widget.defaultStack.toStringAsFixed(0) : 'Stack amount',
                        hintStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
                        filled: true,
                        fillColor: const Color(0xFF101115),
                        suffixIcon: _stackController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _stackController.clear();
                                  setState(() {});
                                },
                                child: const Icon(Icons.close, color: Color(0xFF8C8C8C), size: 18),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF35373C)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF35373C)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF62E3BC)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    ], // end if (!_isMe)

                    const SizedBox(height: 20),

                    // Add button
                    GestureDetector(
                      onTap: _submit,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF62E3BC),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Center(
                          child: Text(
                            _isMe ? 'Move Me Here' : 'Add Player',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.43,
                            ),
                          ),
                        ),
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
