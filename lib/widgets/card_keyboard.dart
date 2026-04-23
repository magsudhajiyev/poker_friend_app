import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared card selection keyboard with three input paths:
/// - Path A: Drag from rank button to suit button
/// - Path B: Tap rank, then swipe in a direction (↑♠ →♥ ↓♦ ←♣)
/// - Path C: Tap rank, then tap suit button (fallback)
class CardKeyboard extends StatefulWidget {
  /// Number of card slots (1, 2, 3, or 5).
  final int slotCount;

  /// Current slot contents. '' = empty, 'A♠' = filled. Length == slotCount.
  final List<String> slots;

  /// Cards that cannot be selected (already used elsewhere).
  final Set<String> excludedCards;

  /// Called when a card is committed to a slot.
  final void Function(int slotIndex, String card) onCardCommitted;

  /// Called when the user taps a filled slot to clear it.
  final void Function(int slotIndex) onCardCleared;

  /// Slots that are pre-filled and cannot be cleared (AllIn dialog).
  final Set<int> lockedSlotIndices;

  const CardKeyboard({
    super.key,
    required this.slotCount,
    required this.slots,
    required this.excludedCards,
    required this.onCardCommitted,
    required this.onCardCleared,
    this.lockedSlotIndices = const {},
  });

  @override
  State<CardKeyboard> createState() => _CardKeyboardState();
}

class _CardKeyboardState extends State<CardKeyboard> {
  static const List<String> _ranks = [
    'A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'
  ];
  static const List<String> _suits = ['♥', '♠', '♦', '♣'];

  // Gesture state
  String? _armedRank;     // Path B/C: rank tapped, awaiting swipe or suit tap
  String? _dragRank;      // Path A: rank being dragged
  String? _hoveredSuit;   // Suit highlighted during drag
  bool _isDragging = false;

  // Keys for hit testing
  final GlobalKey _suitRowKey = GlobalKey();
  final List<GlobalKey> _suitKeys = List.generate(4, (_) => GlobalKey());

  /// Find the next empty non-locked slot index.
  int _findNextEmptySlot() {
    for (int i = 0; i < widget.slots.length; i++) {
      if (widget.slots[i].isEmpty && !widget.lockedSlotIndices.contains(i)) {
        return i;
      }
    }
    return -1;
  }

  /// Check if a specific card is excluded.
  bool _isCardExcluded(String rank, String suit) {
    return widget.excludedCards.contains('$rank$suit');
  }

  /// Check if all 4 suits of a rank are excluded.
  bool _isRankFullyExcluded(String rank) {
    return _suits.every((suit) => _isCardExcluded(rank, suit));
  }

  /// Commit a card to the next empty slot.
  void _commitCard(String rank, String suit) {
    final slotIndex = _findNextEmptySlot();
    if (slotIndex == -1) return;
    if (_isCardExcluded(rank, suit)) return;

    HapticFeedback.lightImpact();
    widget.onCardCommitted(slotIndex, '$rank$suit');

    setState(() {
      _armedRank = null;
      _dragRank = null;
      _hoveredSuit = null;
      _isDragging = false;
    });
  }

  /// Resolve a global position to a suit index by checking suit button bounds.
  String? _resolveSuitAtPosition(Offset globalPosition) {
    for (int i = 0; i < 4; i++) {
      final key = _suitKeys[i];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;
      final pos = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final rect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      if (rect.contains(globalPosition)) {
        return _suits[i];
      }
    }
    return null;
  }

  /// Map swipe velocity to a suit direction.
  String? _resolveVelocityToSuit(Velocity velocity) {
    final dx = velocity.pixelsPerSecond.dx;
    final dy = velocity.pixelsPerSecond.dy;
    if (dx.abs() < 200 && dy.abs() < 200) return null;
    if (dy.abs() > dx.abs()) {
      return dy < 0 ? '♠' : '♦'; // up = spades, down = diamonds
    } else {
      return dx > 0 ? '♥' : '♣'; // right = hearts, left = clubs
    }
  }

  // ─── Path A: Drag from rank ───

  void _onRankPanStart(String rank, DragStartDetails details) {
    if (_isRankFullyExcluded(rank)) return;
    if (_findNextEmptySlot() == -1) return;
    setState(() {
      _dragRank = rank;
      _armedRank = null;
      _isDragging = true;
      _hoveredSuit = null;
    });
  }

  void _onRankPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _dragRank == null) return;
    final suit = _resolveSuitAtPosition(details.globalPosition);
    if (suit != _hoveredSuit) {
      setState(() => _hoveredSuit = suit);
      if (suit != null) HapticFeedback.selectionClick();
    }
  }

  void _onRankPanEnd(DragEndDetails details) {
    if (!_isDragging || _dragRank == null) {
      setState(() {
        _isDragging = false;
        _dragRank = null;
        _hoveredSuit = null;
      });
      return;
    }

    final rank = _dragRank!;
    // Try hovered suit first, then velocity-based fallback
    final suit = _hoveredSuit ?? _resolveVelocityToSuit(details.velocity);

    setState(() {
      _isDragging = false;
      _dragRank = null;
      _hoveredSuit = null;
    });

    if (suit != null && !_isCardExcluded(rank, suit)) {
      _commitCard(rank, suit);
    }
  }

  // ─── Path B: Tap rank, then swipe ───

  void _onRankTap(String rank) {
    if (_isRankFullyExcluded(rank)) return;
    if (_findNextEmptySlot() == -1) return;
    setState(() {
      _armedRank = (_armedRank == rank) ? null : rank;
      _dragRank = null;
      _hoveredSuit = null;
    });
  }

  // ─── Path C: Tap suit button ───

  void _onSuitTap(String suit) {
    final rank = _armedRank ?? _dragRank;
    if (rank == null) return;
    if (_isCardExcluded(rank, suit)) return;
    _commitCard(rank, suit);
  }

  // ─── Outer keyboard swipe (Path B completion) ───

  void _onOuterPanStart(DragStartDetails details) {
    // Path B: only track if a rank is armed and we're not already dragging
  }

  void _onOuterPanEnd(DragEndDetails details) {
    if (_armedRank == null || _isDragging) return;

    final rank = _armedRank!;
    final suit = _resolveVelocityToSuit(details.velocity);

    if (suit != null && !_isCardExcluded(rank, suit)) {
      _commitCard(rank, suit);
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final hasActiveRank = _armedRank != null || _dragRank != null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onOuterPanStart,
      onPanEnd: _onOuterPanEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card slots
          _buildCardSlots(),
          const SizedBox(height: 14),
          // Rank + Suit keyboard
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF02050B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1B1E24), width: 1),
            ),
            child: Column(
              children: [
                // Row 1: A K Q J T 9 8
                _buildRankRow(_ranks.sublist(0, 7)),
                const SizedBox(height: 6),
                // Row 2: 7 6 5 4 3 2 (centered with spacers)
                _buildRankRow(_ranks.sublist(7, 13)),
                const SizedBox(height: 8),
                // 4 suit buttons, always visible
                _buildSuitRow(hasActiveRank),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSlots() {
    final nextEmpty = _findNextEmptySlot();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.slotCount, (i) {
        if (i > 0) return _buildSlotWithGap(i, nextEmpty);
        return _buildCardSlot(i, nextEmpty);
      }),
    );
  }

  Widget _buildSlotWithGap(int index, int nextEmpty) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        _buildCardSlot(index, nextEmpty),
      ],
    );
  }

  Widget _buildCardSlot(int index, int nextEmpty) {
    final card = widget.slots[index];
    final isEmpty = card.isEmpty;
    final isLocked = widget.lockedSlotIndices.contains(index);
    final isActive = index == nextEmpty;

    return GestureDetector(
      onTap: (!isEmpty && !isLocked) ? () => widget.onCardCleared(index) : null,
      child: Container(
        width: 48,
        height: 66,
        decoration: BoxDecoration(
          color: isLocked
              ? const Color(0xFF1B3A2A)
              : isEmpty
                  ? const Color(0xFF1B1E24)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF89F1EC)
                : isLocked
                    ? const Color(0xFF2A5A3A)
                    : isEmpty
                        ? const Color(0xFF35373C)
                        : Colors.grey[400]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.ibmPlexSans(
                    color: const Color(0xFF4E5054),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Stack(
                children: [
                  Center(
                    child: Text(
                      card,
                      style: GoogleFonts.ibmPlexSans(
                        color: _getCardColor(card),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isLocked)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFF35373C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildRankRow(List<String> ranks) {
    return Row(
      children: ranks.map((rank) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildRankButton(rank),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRankButton(String rank) {
    final isFullyExcluded = _isRankFullyExcluded(rank);
    final isArmed = _armedRank == rank;
    final isDragging = _dragRank == rank;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onRankTap(rank),
      onPanStart: (d) => _onRankPanStart(rank, d),
      onPanUpdate: _onRankPanUpdate,
      onPanEnd: _onRankPanEnd,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDragging
              ? const Color(0xFF89F1EC).withValues(alpha: 0.25)
              : isArmed
                  ? const Color(0xFF89F1EC).withValues(alpha: 0.15)
                  : isFullyExcluded
                      ? const Color(0xFF0A0A0E)
                      : const Color(0xFF1B1E24),
          border: Border.all(
            color: (isArmed || isDragging)
                ? const Color(0xFF89F1EC)
                : isFullyExcluded
                    ? const Color(0xFF1B1E24)
                    : const Color(0xFF35373C),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            rank,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: (isArmed || isDragging)
                  ? const Color(0xFF89F1EC)
                  : isFullyExcluded
                      ? const Color(0xFF35373C)
                      : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuitRow(bool hasActiveRank) {
    final activeRank = _armedRank ?? _dragRank;

    return Row(
      key: _suitRowKey,
      children: List.generate(4, (i) {
        final suit = _suits[i];
        final isHovered = _hoveredSuit == suit;
        final isExcluded = activeRank != null && _isCardExcluded(activeRank, suit);
        final suitColor = _getSuitColor(suit);

        return Expanded(
          key: _suitKeys[i],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => _onSuitTap(suit),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 56,
                decoration: BoxDecoration(
                  color: isHovered
                      ? const Color(0xFF89F1EC).withValues(alpha: 0.2)
                      : isExcluded
                          ? const Color(0xFF0A0A0E)
                          : const Color(0xFF1B1E24),
                  border: Border.all(
                    color: isHovered
                        ? const Color(0xFF89F1EC)
                        : (hasActiveRank && !isExcluded)
                            ? const Color(0xFF89F1EC).withValues(alpha: 0.4)
                            : isExcluded
                                ? const Color(0xFF1B1E24)
                                : const Color(0xFF35373C),
                    width: isHovered ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    suit,
                    style: TextStyle(
                      fontSize: isHovered ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: isExcluded
                          ? const Color(0xFF35373C)
                          : suitColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _getCardColor(String card) {
    if (card.isEmpty || card.length == 1) return Colors.grey;
    if (card.contains('♥') || card.contains('♦')) return const Color(0xFFE85D5D);
    return const Color(0xFF2D2D2D);
  }

  Color _getSuitColor(String suit) {
    if (suit == '♥' || suit == '♦') return const Color(0xFFE85D5D);
    return Colors.white;
  }
}
