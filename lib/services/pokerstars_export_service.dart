import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Converts hand data from our app format into PokerStars hand history
/// text format, suitable for import into common solver/study tools.
///
/// All methods are static. The service handles:
/// - Card symbol conversion (♠→s, ♥→h, ♦→d, ♣→c)
/// - Implicit blind posting generation (blinds are not in our action list)
/// - BB ante handling
/// - Preflop raise format (TOTAL stored → "raises X to Y")
/// - Postflop raise format (ADDITIONAL stored → "raises X to Y")
/// - Starting stack reconstruction from first action + blinds
/// - Uncalled bet detection
/// - Dealer mode action filtering (skip blind/ante action strings)
class PokerStarsExportService {
  // Private constructor — static methods only
  PokerStarsExportService._();

  // ───────────────────────────────────────────────────────────
  // Card conversion
  // ───────────────────────────────────────────────────────────

  static const _suitMap = {
    '♠': 's',
    '♥': 'h',
    '♦': 'd',
    '♣': 'c',
  };

  /// Convert a single card from our format to PokerStars format.
  /// 'A♠' → 'As', 'T♥' → 'Th', '10♠' → 'Ts'
  static String _convertCard(String card) {
    if (card.isEmpty) return card;
    // Handle '10' rank — PokerStars uses 'T'
    String working = card.replaceAll('10', 'T');
    for (final entry in _suitMap.entries) {
      working = working.replaceAll(entry.key, entry.value);
    }
    return working;
  }

  /// Format a list of cards into PokerStars bracket notation.
  /// ['A♠', 'K♥', 'Q♦'] → '[As Kh Qd]'
  static String _formatCards(List<String> cards) {
    return '[${cards.map(_convertCard).join(' ')}]';
  }

  // ───────────────────────────────────────────────────────────
  // Amount formatting
  // ───────────────────────────────────────────────────────────

  /// Format an amount: whole numbers as int, otherwise 2 decimal places.
  static String _fmtAmt(double amount) {
    if (amount == amount.roundToDouble() && amount.abs() < 1e15) {
      return amount.toInt().toString();
    }
    // Remove trailing zeros from decimal representation
    String s = amount.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ───────────────────────────────────────────────────────────
  // Seat / position helpers
  // ───────────────────────────────────────────────────────────

  /// Get the list of active seat numbers from playerNames map.
  static List<int> _getActiveSeats(Map<String, dynamic> hand) {
    final playerNames = _getPlayerNames(hand);
    final seats = playerNames.keys.toList()..sort();
    return seats;
  }

  /// Parse playerNames from hand data. Returns Map<int, String>.
  /// Hero's actual name is replaced with "Hero" based on heroSeatNumber.
  ///
  /// Names are sanitized HERE and blank names become "Player {seat}": a
  /// seat stored with an empty name otherwise produces lines like
  /// ": raises 3000" and "Seat 3:  (49200 in chips)", which hand-history
  /// parsers (solver tools etc.) reject.
  static Map<int, String> _getPlayerNames(Map<String, dynamic> hand) {
    final raw = hand['playerNames'] as Map<String, dynamic>? ?? {};
    final heroSeat = hand['heroSeatNumber'] as int?;
    final result = <int, String>{};
    raw.forEach((key, value) {
      final seat = int.tryParse(key);
      if (seat != null && value != null) {
        if (seat == heroSeat) {
          result[seat] = 'Hero';
        } else {
          final name = _sanitizeName(value.toString());
          result[seat] = name.isEmpty ? 'Player $seat' : name;
        }
      }
    });
    return result;
  }

  /// Find SB and BB seats from the actions' playerPosition field,
  /// falling back to computing from buttonPosition and active seats.
  static ({int sb, int bb}) _findBlindSeats(
    Map<String, dynamic> hand,
    List<int> activeSeats,
  ) {
    final actions = _getActions(hand);
    int? sbSeat;
    int? bbSeat;

    // First try: look at playerPosition in actions
    for (final a in actions) {
      final pos = (a['playerPosition'] as String?)?.toUpperCase() ?? '';
      final seat = a['player'] as int? ?? 0;
      if (pos == 'SB' && sbSeat == null) sbSeat = seat;
      if (pos == 'BB' && bbSeat == null) bbSeat = seat;
      // Heads-up: BTN/SB is the small blind
      if (pos == 'BTN/SB' && sbSeat == null) sbSeat = seat;
      if (sbSeat != null && bbSeat != null) break;
    }

    // Second try: look for dealer mode blind actions
    if (sbSeat == null || bbSeat == null) {
      for (final a in actions) {
        final actionType = (a['action'] as String?)?.toLowerCase() ?? '';
        final seat = a['player'] as int? ?? 0;
        if (actionType == 'small blind' && sbSeat == null) sbSeat = seat;
        if (actionType == 'big blind' && bbSeat == null) bbSeat = seat;
        if (sbSeat != null && bbSeat != null) break;
      }
    }

    // Third try: compute from button position
    if (sbSeat == null || bbSeat == null) {
      final btn = hand['buttonPosition'] as int? ?? 1;
      final sorted = List<int>.from(activeSeats)..sort();
      if (sorted.length >= 2) {
        final btnIdx = sorted.indexOf(btn);
        if (btnIdx != -1) {
          if (sorted.length == 2) {
            // Heads-up: button IS the SB
            sbSeat ??= sorted[btnIdx];
            bbSeat ??= sorted[(btnIdx + 1) % sorted.length];
          } else {
            sbSeat ??= sorted[(btnIdx + 1) % sorted.length];
            bbSeat ??= sorted[(btnIdx + 2) % sorted.length];
          }
        } else {
          // Button not in active seats — pick first two after btn value
          int startIdx = 0;
          for (int i = 0; i < sorted.length; i++) {
            if (sorted[i] > btn) {
              startIdx = i;
              break;
            }
          }
          sbSeat ??= sorted[startIdx % sorted.length];
          bbSeat ??= sorted[(startIdx + 1) % sorted.length];
        }
      }
    }

    return (sb: sbSeat ?? 0, bb: bbSeat ?? 0);
  }

  /// Safely extract actions list.
  static List<Map<String, dynamic>> _getActions(Map<String, dynamic> hand) {
    final raw = hand['actions'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  /// Check whether an action string is a dealer-mode blind/ante posting.
  static bool _isDealerBlindAction(String actionType) {
    final t = actionType.toLowerCase();
    return t == 'small blind' || t == 'big blind' || t == 'ante';
  }

  // ───────────────────────────────────────────────────────────
  // Starting stack reconstruction
  // ───────────────────────────────────────────────────────────

  /// Reconstruct starting stacks from each player's first action.
  /// The playerStack in an action is the stack AFTER blinds have been
  /// deducted, so we add back what the player posted.
  static Map<int, double> _getStartingStacks(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    final actions = _getActions(hand);
    final activeSeats = _getActiveSeats(hand);
    final blinds = _findBlindSeats(hand, activeSeats);
    final sb = (hand['smallBlind'] ?? session['smallBlind'] ?? 0).toDouble();
    final bb = (hand['bigBlind'] ?? session['bigBlind'] ?? 0).toDouble();
    final hasBBante = session['hasBBante'] == true;
    final playerCount = activeSeats.length;
    final antePerPlayer = (hasBBante && playerCount > 0) ? bb / playerCount : 0.0;

    final stacks = <int, double>{};

    for (final a in actions) {
      final seat = a['player'] as int? ?? 0;
      if (seat == 0 || stacks.containsKey(seat)) continue;
      final stack = (a['playerStack'] as num?)?.toDouble();
      if (stack == null) continue;

      // playerStack = stack at time of first action (after blinds/ante deducted).
      // We need to reconstruct the starting stack BEFORE any postings.
      double starting = stack;
      if (seat == blinds.sb) {
        starting += sb;
        if (hasBBante) starting += antePerPlayer;
      } else if (seat == blinds.bb) {
        starting += bb;
        if (hasBBante) {
          // Our app deducted full bb as ante from BB. In the export, BB
          // only posts antePerPlayer. Add back the full bb (real deduction)
          // to get the true starting stack.
          starting += bb;
        }
      } else {
        if (hasBBante) starting += antePerPlayer;
      }
      stacks[seat] = starting;
    }

    return stacks;
  }

  // ───────────────────────────────────────────────────────────
  // Hand ID generation
  // ───────────────────────────────────────────────────────────

  /// Generate a deterministic PokerStars-style hand ID from session ID
  /// and hand number.
  static String _generateHandId(String? sessionId, int handNumber) {
    // Use a hash of the session ID + hand number for a stable numeric ID
    final base = '${sessionId ?? 'local'}_$handNumber';
    int hash = 0;
    for (int i = 0; i < base.length; i++) {
      hash = (hash * 31 + base.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    // Ensure it looks like a real hand ID (12 digits)
    final id = (hash % 900000000000 + 100000000000);
    return id.toString();
  }

  /// Generate a tournament ID from session data.
  static String _generateTournamentId(String? sessionId) {
    final base = sessionId ?? 'local_tourney';
    int hash = 0;
    for (int i = 0; i < base.length; i++) {
      hash = (hash * 37 + base.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return (hash % 9000000000 + 1000000000).toString();
  }

  // ───────────────────────────────────────────────────────────
  // Header
  // ───────────────────────────────────────────────────────────

  static String _buildHeader(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    final handNumber = hand['handNumber'] ?? 1;
    final sessionId = session['sessionId'] as String? ??
        session['id'] as String? ??
        hand['sessionId'] as String?;
    final handId = _generateHandId(sessionId, handNumber);
    final sb = (hand['smallBlind'] ?? session['smallBlind'] ?? 0);
    final bb = (hand['bigBlind'] ?? session['bigBlind'] ?? 0);
    final gameType =
        (hand['gameType'] ?? session['gameType'] ?? 'cash').toString().toLowerCase();

    // Parse start time
    DateTime startTime;
    final rawTime = hand['startTime'];
    if (rawTime is DateTime) {
      startTime = rawTime;
    } else if (rawTime is String) {
      startTime = DateTime.tryParse(rawTime) ?? DateTime.now();
    } else {
      startTime = DateTime.now();
    }

    final dateStr =
        '${startTime.year}/${startTime.month.toString().padLeft(2, '0')}/${startTime.day.toString().padLeft(2, '0')} '
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}';

    if (gameType == 'tournament') {
      final tourneyId = _generateTournamentId(sessionId);
      final buyIn = (session['buyInAmount'] as num?)?.toDouble() ?? 0;
      final buyInStr = buyIn > 0 ? '\$${_fmtAmt(buyIn)}+\$0.00 USD ' : '';
      return 'PokerStars Hand #$handId: Tournament #$tourneyId, '
          '${buyInStr}Hold\'em No Limit - Level I '
          '(${_fmtAmt(sb.toDouble())}/${_fmtAmt(bb.toDouble())}) - $dateStr';
    } else {
      return 'PokerStars Hand #$handId: Hold\'em No Limit '
          '(\$${_fmtAmt(sb.toDouble())}/\$${_fmtAmt(bb.toDouble())} USD) - $dateStr';
    }
  }

  // ───────────────────────────────────────────────────────────
  // Table line
  // ───────────────────────────────────────────────────────────

  static String _buildTableLine(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    final btn = hand['buttonPosition'] ?? 1;
    final activeSeats = _getActiveSeats(hand);
    final maxSeat = activeSeats.isNotEmpty ? activeSeats.last : 9;
    final tableSize = maxSeat <= 6 ? 6 : (maxSeat <= 8 ? 8 : 9);
    final sessionName = session['sessionName'] ?? 'Table';
    final gameType =
        (hand['gameType'] ?? session['gameType'] ?? 'cash').toString().toLowerCase();

    if (gameType == 'tournament') {
      final sessionId = session['sessionId'] as String? ??
          session['id'] as String? ??
          hand['sessionId'] as String?;
      final tourneyId = _generateTournamentId(sessionId);
      return "Table '$tourneyId 1' $tableSize-max Seat #$btn is the button";
    }
    // Sanitize session name for the table line
    final safeName = sessionName.toString().replaceAll("'", "");
    return "Table '$safeName' $tableSize-max Seat #$btn is the button";
  }

  // ───────────────────────────────────────────────────────────
  // Seat lines
  // ───────────────────────────────────────────────────────────

  static String _buildSeatLines(
    Map<String, dynamic> hand,
    Map<int, double> stacks,
  ) {
    final names = _getPlayerNames(hand);
    final seats = names.keys.toList()..sort();
    final buf = StringBuffer();
    for (final seat in seats) {
      final name = _sanitizeName(names[seat] ?? 'Player $seat');
      final stack = stacks[seat] ?? 0;
      buf.writeln('Seat $seat: $name (${_fmtAmt(stack)} in chips)');
    }
    return buf.toString().trimRight();
  }

  /// Replace characters that could break parsing.
  static String _sanitizeName(String name) {
    return name.replaceAll(':', '').replaceAll('\n', ' ').trim();
  }

  // ───────────────────────────────────────────────────────────
  // Blind (and ante) lines
  // ───────────────────────────────────────────────────────────

  static String _buildBlindLines(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    final names = _getPlayerNames(hand);
    final activeSeats = _getActiveSeats(hand);
    final blinds = _findBlindSeats(hand, activeSeats);
    final sb = (hand['smallBlind'] ?? session['smallBlind'] ?? 0).toDouble();
    final bb = (hand['bigBlind'] ?? session['bigBlind'] ?? 0).toDouble();
    final hasBBante = session['hasBBante'] == true;
    final playerCount = activeSeats.length;

    final sbName = _sanitizeName(names[blinds.sb] ?? 'Player ${blinds.sb}');
    final bbName = _sanitizeName(names[blinds.bb] ?? 'Player ${blinds.bb}');

    final buf = StringBuffer();

    // Antes come BEFORE blinds in PokerStars format.
    // Our app uses BB ante (only BB posts), but solver tools expect
    // per-player ante lines. Convert: BB ante total / playerCount = per-player ante.
    if (hasBBante && playerCount > 0) {
      final antePerPlayer = bb / playerCount;
      final seats = List<int>.from(activeSeats)..sort();
      for (final seat in seats) {
        final name = _sanitizeName(names[seat] ?? 'Player $seat');
        buf.writeln('$name: posts the ante ${_fmtAmt(antePerPlayer)}');
      }
    }

    buf.writeln('$sbName: posts small blind ${_fmtAmt(sb)}');
    buf.writeln('$bbName: posts big blind ${_fmtAmt(bb)}');
    return buf.toString().trimRight();
  }

  // ───────────────────────────────────────────────────────────
  // Hole cards
  // ───────────────────────────────────────────────────────────

  static String _buildHoleCards(Map<String, dynamic> hand) {
    final buf = StringBuffer();
    buf.writeln('*** HOLE CARDS ***');

    final holeCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    if (holeCards != null) {
      final c1 = holeCards['card1'] as String?;
      final c2 = holeCards['card2'] as String?;
      if (c1 != null && c2 != null && c1.isNotEmpty && c2.isNotEmpty) {
        buf.writeln('Dealt to Hero [${_convertCard(c1)} ${_convertCard(c2)}]');
      }
    }
    return buf.toString().trimRight();
  }

  // ───────────────────────────────────────────────────────────
  // Street actions
  // ───────────────────────────────────────────────────────────

  static String _buildStreetActions(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    final actions = _getActions(hand);
    final names = _getPlayerNames(hand);
    final bb = (hand['bigBlind'] ?? session['bigBlind'] ?? 0).toDouble();
    final sb = (hand['smallBlind'] ?? session['smallBlind'] ?? 0).toDouble();
    final hasBBante = session['hasBBante'] == true;
    final activeSeats = _getActiveSeats(hand);
    final blinds = _findBlindSeats(hand, activeSeats);
    final boardCards = hand['boardCards'] as Map<String, dynamic>?;

    final buf = StringBuffer();

    // Group actions by street
    final streetOrder = ['preflop', 'flop', 'turn', 'river'];
    final actionsByStreet = <String, List<Map<String, dynamic>>>{};
    for (final street in streetOrder) {
      actionsByStreet[street] = [];
    }
    for (final a in actions) {
      final street = (a['street'] as String?)?.toLowerCase() ?? 'preflop';
      actionsByStreet.putIfAbsent(street, () => []);
      actionsByStreet[street]!.add(a);
    }

    // Track the current bet level and each player's committed amount per street
    for (final street in streetOrder) {
      final streetActions = actionsByStreet[street] ?? [];
      if (streetActions.isEmpty && street != 'preflop') continue;

      // Emit street header (preflop header is HOLE CARDS, handled separately)
      if (street == 'flop' && boardCards != null) {
        final flop = (boardCards['flop'] as List<dynamic>?)?.cast<String>() ?? [];
        if (flop.isNotEmpty) {
          buf.writeln('*** FLOP *** ${_formatCards(flop)}');
        }
      } else if (street == 'turn' && boardCards != null) {
        final flop = (boardCards['flop'] as List<dynamic>?)?.cast<String>() ?? [];
        final turn = boardCards['turn'] as String?;
        if (turn != null && turn.isNotEmpty) {
          buf.writeln(
              '*** TURN *** ${_formatCards(flop)} [${_convertCard(turn)}]');
        }
      } else if (street == 'river' && boardCards != null) {
        final flop = (boardCards['flop'] as List<dynamic>?)?.cast<String>() ?? [];
        final turn = boardCards['turn'] as String?;
        final river = boardCards['river'] as String?;
        if (river != null && river.isNotEmpty) {
          final boardSoFar = [...flop, if (turn != null) turn];
          buf.writeln(
              '*** RIVER *** ${_formatCards(boardSoFar)} [${_convertCard(river)}]');
        }
      }

      // Track bet level for this street
      double currentBetLevel = 0;
      final committed = <int, double>{}; // seat → amount committed this street

      if (street == 'preflop') {
        // Blinds set the initial bet level
        currentBetLevel = bb;
        committed[blinds.sb] = sb;
        committed[blinds.bb] = bb;
        if (hasBBante) {
          // BB ante goes into pot but doesn't change the bet level
        }
      }

      for (final a in streetActions) {
        final seat = a['player'] as int? ?? 0;
        final actionType = (a['action'] as String?)?.toLowerCase() ?? '';
        final amount = (a['amount'] as num?)?.toDouble();
        final name = _sanitizeName(names[seat] ?? 'Player $seat');

        // Skip dealer mode blind/ante actions — we generate those separately
        if (_isDealerBlindAction(actionType)) continue;

        if (actionType == 'fold') {
          buf.writeln('$name: folds');
        } else if (actionType == 'check') {
          buf.writeln('$name: checks');
        } else if (actionType == 'call') {
          final callAmt = amount ?? (currentBetLevel - (committed[seat] ?? 0));
          final effectiveCall = callAmt > 0 ? callAmt : currentBetLevel - (committed[seat] ?? 0);
          committed[seat] = (committed[seat] ?? 0) + effectiveCall;
          // HL-8: PokerStars marks a call for the whole stack as all-in.
          final stackAtAction = (a['playerStack'] as num?)?.toDouble();
          final callIsAllIn = stackAtAction != null &&
              stackAtAction > 0 &&
              effectiveCall >= stackAtAction - 0.01;
          buf.writeln(callIsAllIn
              ? '$name: calls ${_fmtAmt(effectiveCall)} and is all-in'
              : '$name: calls ${_fmtAmt(effectiveCall)}');
        } else if (actionType == 'bet') {
          final betAmt = amount ?? 0;
          currentBetLevel = betAmt;
          committed[seat] = betAmt;
          buf.writeln('$name: bets ${_fmtAmt(betAmt)}');
        } else if (actionType == 'raise') {
          if (street == 'preflop') {
            // Preflop: amount is TOTAL (raise TO).
            final totalAmount = amount ?? 0;
            final previouslyCommitted = committed[seat] ?? 0;
            final additional = totalAmount - currentBetLevel;
            currentBetLevel = totalAmount;
            committed[seat] = totalAmount;
            if (additional > 0) {
              buf.writeln(
                  '$name: raises ${_fmtAmt(additional)} to ${_fmtAmt(totalAmount)}');
            } else {
              // Edge case: amount equals current bet level — treat as call
              // but label as raise with 0 additional
              buf.writeln(
                  '$name: raises ${_fmtAmt(totalAmount - (previouslyCommitted))} to ${_fmtAmt(totalAmount)}');
            }
          } else {
            // Postflop: amount is ADDITIONAL (raise BY).
            final additionalAmount = amount ?? 0;
            final newTotal = currentBetLevel + additionalAmount;
            currentBetLevel = newTotal;
            committed[seat] = (committed[seat] ?? 0) + additionalAmount + (currentBetLevel - additionalAmount - (committed[seat] ?? 0));
            // Recalculate: player must match previous bet + raise
            committed[seat] = newTotal;
            buf.writeln(
                '$name: raises ${_fmtAmt(additionalAmount)} to ${_fmtAmt(newTotal)}');
          }
        } else if (actionType == 'all-in') {
          // All-in: treat as bet or raise depending on context
          final allInAmt = amount ?? 0;
          if (currentBetLevel == 0) {
            // No bet yet — this is a bet (all-in)
            currentBetLevel = allInAmt;
            committed[seat] = allInAmt;
            buf.writeln('$name: bets ${_fmtAmt(allInAmt)}');
          } else if (allInAmt > currentBetLevel) {
            // Raising all-in
            if (street == 'preflop') {
              // allInAmt is total
              final additional = allInAmt - currentBetLevel;
              currentBetLevel = allInAmt;
              committed[seat] = allInAmt;
              buf.writeln(
                  '$name: raises ${_fmtAmt(additional)} to ${_fmtAmt(allInAmt)} and is all-in');
            } else {
              // Postflop all-in: amount could be additional or total.
              // Heuristic: if allInAmt > currentBetLevel, it's likely the
              // total the player is putting in, so additional = allInAmt - currentBetLevel.
              // But our data stores postflop raises as ADDITIONAL, so allInAmt IS additional.
              final additional = allInAmt;
              final newTotal = currentBetLevel + additional;
              currentBetLevel = newTotal;
              committed[seat] = newTotal;
              buf.writeln(
                  '$name: raises ${_fmtAmt(additional)} to ${_fmtAmt(newTotal)} and is all-in');
            }
          } else {
            // Calling all-in (for less or equal)
            final callAmt = allInAmt > 0
                ? allInAmt
                : (currentBetLevel - (committed[seat] ?? 0));
            committed[seat] = (committed[seat] ?? 0) + callAmt;
            buf.writeln('$name: calls ${_fmtAmt(callAmt)} and is all-in');
          }
        }
        // Unknown action types are silently skipped
      }
    }

    return buf.toString().trimRight();
  }

  // ───────────────────────────────────────────────────────────
  // Result (collected / uncalled bet)
  // ───────────────────────────────────────────────────────────

  static String _buildResult(Map<String, dynamic> hand) {
    final names = _getPlayerNames(hand);
    final pot = (hand['potAmount'] as num?)?.toDouble() ?? 0;
    final isChopped = hand['isChoppedPot'] == true;
    final buf = StringBuffer();

    // Compute uncalled bet if the hand ended without showdown
    final uncalled = _computeUncalledBet(hand);
    if (uncalled != null && uncalled.amount > 0) {
      final name =
          _sanitizeName(names[uncalled.seat] ?? 'Player ${uncalled.seat}');
      buf.writeln(
          'Uncalled bet (${_fmtAmt(uncalled.amount)}) returned to $name');
    }

    if (isChopped) {
      final winners =
          (hand['choppedWinners'] as List<dynamic>?)?.cast<int>() ?? [];
      final shares =
          hand['individualShares'] as Map<String, dynamic>? ?? {};
      final sharePerWinner =
          (hand['sharePerWinner'] as num?)?.toDouble();

      for (final seat in winners) {
        final name = _sanitizeName(names[seat] ?? 'Player $seat');
        double amt;
        if (shares.containsKey(seat.toString())) {
          amt = (shares[seat.toString()] as num).toDouble();
        } else if (sharePerWinner != null) {
          amt = sharePerWinner;
        } else {
          amt = pot / winners.length;
        }
        buf.writeln('$name collected ${_fmtAmt(amt)} from pot');
      }
    } else {
      final winnerId = hand['winnerId'] as int?;
      if (winnerId != null) {
        final name = _sanitizeName(names[winnerId] ?? 'Player $winnerId');
        // Pot after removing uncalled bet
        final collectedPot =
            uncalled != null ? pot - uncalled.amount : pot;
        buf.writeln(
            '$name collected ${_fmtAmt(collectedPot > 0 ? collectedPot : pot)} from pot');
      }
    }

    return buf.toString().trimRight();
  }

  /// Compute uncalled bet: if the last aggressor's bet was not fully called.
  static ({int seat, double amount})? _computeUncalledBet(
    Map<String, dynamic> hand,
  ) {
    final reached = hand['reachedShowdown'] == true;
    if (reached) return null; // No uncalled bet at showdown

    final actions = _getActions(hand);
    if (actions.isEmpty) return null;

    // Walk actions in reverse to find the last aggressive action
    // and check if it was called.
    // Find the last street that had actions
    String? lastStreet;
    for (int i = actions.length - 1; i >= 0; i--) {
      final a = actions[i];
      final actionType = (a['action'] as String?)?.toLowerCase() ?? '';
      if (_isDealerBlindAction(actionType)) continue;
      lastStreet = (a['street'] as String?)?.toLowerCase();
      break;
    }
    if (lastStreet == null) return null;

    // Gather actions for the last street
    final streetActions = actions.where((a) {
      final s = (a['street'] as String?)?.toLowerCase();
      final t = (a['action'] as String?)?.toLowerCase() ?? '';
      return s == lastStreet && !_isDealerBlindAction(t);
    }).toList();

    // Find the last aggressive action (bet, raise, all-in as raise)
    int? lastAggressorSeat;
    double lastAggressorTotal = 0;
    double highestCallOrCommit = 0;
    final committed = <int, double>{};

    for (final a in streetActions) {
      final seat = a['player'] as int? ?? 0;
      final actionType = (a['action'] as String?)?.toLowerCase() ?? '';
      final amount = (a['amount'] as num?)?.toDouble() ?? 0;

      if (actionType == 'bet') {
        committed[seat] = amount;
        lastAggressorSeat = seat;
        lastAggressorTotal = amount;
      } else if (actionType == 'raise') {
        if (lastStreet == 'preflop') {
          committed[seat] = amount; // total
          lastAggressorSeat = seat;
          lastAggressorTotal = amount;
        } else {
          // Postflop raise: additional
          final newTotal = (committed.values.isEmpty
                  ? 0
                  : committed.values
                      .reduce((a, b) => a > b ? a : b)) +
              amount;
          committed[seat] = newTotal;
          lastAggressorSeat = seat;
          lastAggressorTotal = newTotal;
        }
      } else if (actionType == 'all-in') {
        committed[seat] = (committed[seat] ?? 0) + amount;
        if (committed[seat]! > lastAggressorTotal) {
          lastAggressorSeat = seat;
          lastAggressorTotal = committed[seat]!;
        }
      } else if (actionType == 'call') {
        committed[seat] = (committed[seat] ?? 0) + amount;
        if (committed[seat]! > highestCallOrCommit) {
          highestCallOrCommit = committed[seat]!;
        }
      } else if (actionType == 'fold' || actionType == 'check') {
        // No change to committed
      }
    }

    if (lastAggressorSeat == null) return null;

    // Find the highest amount committed by any OTHER player
    double maxOtherCommit = 0;
    committed.forEach((seat, amt) {
      if (seat != lastAggressorSeat && amt > maxOtherCommit) {
        maxOtherCommit = amt;
      }
    });

    final uncalled = lastAggressorTotal - maxOtherCommit;
    if (uncalled > 0) {
      return (seat: lastAggressorSeat, amount: uncalled);
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────
  // Showdown
  // ───────────────────────────────────────────────────────────

  static String _buildShowdown(Map<String, dynamic> hand) {
    if (hand['reachedShowdown'] != true) return '';

    final buf = StringBuffer();
    buf.writeln('*** SHOW DOWN ***');

    final showdown = hand['showdownData'] as Map<String, dynamic>?;
    final names = _getPlayerNames(hand);

    if (showdown != null) {
      final playerCards =
          showdown['playerCards'] as Map<String, dynamic>? ?? {};
      playerCards.forEach((seatStr, cardsData) {
        final seat = int.tryParse(seatStr);
        if (seat == null) return;
        final cards = cardsData as Map<String, dynamic>? ?? {};
        final c1 = cards['card1'] as String?;
        final c2 = cards['card2'] as String?;
        if (c1 != null && c2 != null && c1.isNotEmpty && c2.isNotEmpty) {
          final name = _sanitizeName(names[seat] ?? 'Player $seat');
          buf.writeln(
              '$name: shows [${_convertCard(c1)} ${_convertCard(c2)}]');
        }
      });
    }

    return buf.toString().trimRight();
  }

  // ───────────────────────────────────────────────────────────
  // Summary
  // ───────────────────────────────────────────────────────────

  static String _buildSummary(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    final pot = (hand['potAmount'] as num?)?.toDouble() ?? 0;
    final names = _getPlayerNames(hand);
    final activeSeats = _getActiveSeats(hand);
    final blinds = _findBlindSeats(hand, activeSeats);
    final btn = hand['buttonPosition'] as int? ?? 1;
    final boardCards = hand['boardCards'] as Map<String, dynamic>?;
    final reached = hand['reachedShowdown'] == true;
    final winnerId = hand['winnerId'] as int?;
    final isChopped = hand['isChoppedPot'] == true;
    final choppedWinners =
        (hand['choppedWinners'] as List<dynamic>?)?.cast<int>() ?? [];
    final actions = _getActions(hand);

    final buf = StringBuffer();
    buf.writeln('*** SUMMARY ***');
    buf.writeln('Total pot ${_fmtAmt(pot)} | Rake 0');

    // Board line
    if (boardCards != null) {
      final flop =
          (boardCards['flop'] as List<dynamic>?)?.cast<String>() ?? [];
      final turn = boardCards['turn'] as String?;
      final river = boardCards['river'] as String?;
      final allCards = [
        ...flop,
        if (turn != null && turn.isNotEmpty) turn,
        if (river != null && river.isNotEmpty) river,
      ];
      if (allCards.isNotEmpty) {
        buf.writeln('Board ${_formatCards(allCards)}');
      }
    }

    // Per-seat summary
    final seats = names.keys.toList()..sort();
    for (final seat in seats) {
      final name = _sanitizeName(names[seat] ?? 'Player $seat');

      // Position label
      String posLabel = '';
      if (seat == btn) {
        posLabel = ' (button)';
      } else if (seat == blinds.sb) {
        posLabel = ' (small blind)';
      } else if (seat == blinds.bb) {
        posLabel = ' (big blind)';
      }

      // Determine what happened to this player
      final isWinner = isChopped
          ? choppedWinners.contains(seat)
          : seat == winnerId;

      if (isWinner) {
        // Compute amount collected
        double collected = pot;
        if (isChopped) {
          final shares =
              hand['individualShares'] as Map<String, dynamic>? ?? {};
          if (shares.containsKey(seat.toString())) {
            collected = (shares[seat.toString()] as num).toDouble();
          } else if (hand['sharePerWinner'] != null) {
            collected = (hand['sharePerWinner'] as num).toDouble();
          } else {
            collected = pot / choppedWinners.length;
          }
        }
        buf.writeln('Seat $seat: $name$posLabel collected (${_fmtAmt(collected)})');
      } else {
        // Did this player fold? If so, when?
        final foldAction = actions.where((a) {
          final s = a['player'] as int? ?? 0;
          final t = (a['action'] as String?)?.toLowerCase() ?? '';
          return s == seat && t == 'fold';
        });

        if (foldAction.isNotEmpty) {
          final foldStreet =
              (foldAction.first['street'] as String?)?.toLowerCase() ??
                  'preflop';

          // Did they put money in before folding?
          final playerActions = actions.where((a) {
            final s = a['player'] as int? ?? 0;
            final t = (a['action'] as String?)?.toLowerCase() ?? '';
            return s == seat && !_isDealerBlindAction(t);
          }).toList();

          // Check if player voluntarily put money in
          final voluntaryAction = playerActions.any((a) {
            final t = (a['action'] as String?)?.toLowerCase() ?? '';
            return t == 'call' || t == 'bet' || t == 'raise' || t == 'all-in';
          });

          if (foldStreet == 'preflop') {
            if (!voluntaryAction && seat != blinds.sb && seat != blinds.bb) {
              buf.writeln(
                  "Seat $seat: $name$posLabel folded before Flop (didn't bet)");
            } else {
              buf.writeln(
                  'Seat $seat: $name$posLabel folded before Flop');
            }
          } else {
            final streetName = _capitalizeStreet(foldStreet);
            buf.writeln(
                'Seat $seat: $name$posLabel folded on the $streetName');
          }
        } else if (reached) {
          // Player went to showdown but lost
          buf.writeln('Seat $seat: $name$posLabel mucked');
        } else {
          // Player didn't fold and hand didn't reach showdown
          // (likely was in a chopped pot scenario or similar)
          buf.writeln('Seat $seat: $name$posLabel mucked');
        }
      }
    }

    return buf.toString().trimRight();
  }

  static String _capitalizeStreet(String street) {
    switch (street) {
      case 'flop':
        return 'Flop';
      case 'turn':
        return 'Turn';
      case 'river':
        return 'River';
      default:
        return street;
    }
  }

  // ───────────────────────────────────────────────────────────
  // PUBLIC API
  // ───────────────────────────────────────────────────────────

  /// Export a single hand to PokerStars hand history format.
  ///
  /// [hand] — hand data map (see HandRecord.toMap())
  /// [session] — session data map
  ///
  /// Returns the full hand history text block.
  static String exportHand(
    Map<String, dynamic> hand,
    Map<String, dynamic> session,
  ) {
    // Ensure we have playerNames at minimum
    if (_getPlayerNames(hand).isEmpty) {
      return ''; // Cannot export without player info
    }

    final stacks = _getStartingStacks(hand, session);

    final sections = <String>[
      _buildHeader(hand, session),
      _buildTableLine(hand, session),
      _buildSeatLines(hand, stacks),
      _buildBlindLines(hand, session),
      _buildHoleCards(hand),
      _buildStreetActions(hand, session),
    ];

    // Showdown (only if reached)
    final showdown = _buildShowdown(hand);
    if (showdown.isNotEmpty) {
      sections.add(showdown);
    }

    // Result
    sections.add(_buildResult(hand));

    // Summary
    sections.add(_buildSummary(hand, session));

    return sections.join('\n');
  }

  /// Export all hands from a session, separated by blank lines.
  ///
  /// [session] — session data map
  /// [hands] — list of hand data maps, will be sorted by handNumber
  ///
  /// Returns the full multi-hand history text.
  static String exportSession(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> hands,
  ) {
    // Sort hands by hand number
    final sorted = List<Map<String, dynamic>>.from(hands)
      ..sort((a, b) =>
          (a['handNumber'] as int? ?? 0).compareTo(b['handNumber'] as int? ?? 0));

    final blocks = <String>[];
    for (final hand in sorted) {
      final block = exportHand(hand, session);
      if (block.isNotEmpty) {
        blocks.add(block);
      }
    }

    return blocks.join('\n\n\n');
  }

  /// Export a single hand to a temporary file and invoke the system share
  /// dialog so the user can send or save the file.
  static Future<void> exportAndShare(
    Map<String, dynamic> hand,
    Map<String, dynamic> session, {
    String? fileName,
    Rect? sharePositionOrigin,
  }) async {
    final text = exportHand(hand, session);
    if (text.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final name =
        fileName ?? 'hand_${hand['handNumber'] ?? 'export'}.txt';
    final file = File('${dir.path}/$name');
    await file.writeAsString(text);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PokerStars Hand History',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Export a full session to a temporary file and share.
  static Future<void> exportSessionAndShare(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> hands, {
    String? fileName,
    Rect? sharePositionOrigin,
  }) async {
    final text = exportSession(session, hands);
    if (text.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final name = fileName ??
        'session_${session['sessionName'] ?? 'export'}.txt';
    final safeName = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsString(text);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PokerStars Hand History',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
