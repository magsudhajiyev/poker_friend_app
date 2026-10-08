import 'board_texture.dart';
import 'flop_strength.dart';
import 'stats_calculator.dart';

/// LEAK DETECTOR (phase 1) — per-hand fact extraction.
///
/// Pure functions: hand map (Firestore/SQLite format, see CLAUDE.md "Hand
/// Data Format") → [LeakHandFacts], the frequency-shaped facts the leak
/// engine aggregates. No money/EV analysis in phase 1 — frequencies
/// converge at live sample sizes, money does not.
///
/// Reuses [StatsCalculator] for every spot it already detects (3-bets,
/// blinds, walks) — never re-derive what is already tested there.
class LeakHandFacts {
  /// Opaque reference for drill-through ('{sessionId}:{handNumber}' in the
  /// app; anything printable in harnesses). Null when caller passes none.
  final String? ref;

  final bool isWalk;

  /// Flop texture (null when no flop was dealt or cards unparsable).
  final BoardTexture? flopTexture;

  /// Hero position group: 'EP' | 'MP' | 'CO' | 'BTN' | 'SB' | 'BB' | null.
  final String? posGroup;

  /// Hero hole cards for display ('A♠K♦'), null when not recorded.
  final String? holeCards;

  /// Hero hand strength on the flop (null without hole cards or flop).
  final FlopStrength? flopStrength;

  // ── Money view (BB-normalized; reconstruction, see _heroInvested) ──
  /// Hero net for the hand in big blinds (winnings − invested), null when
  /// the hand lacks a usable bigBlind.
  final double? netBB;

  /// Hero stack in BB at their first recorded action, null when unknown.
  final double? stackBB;

  /// Position group of the preflop opener hero contested against (the
  /// first voluntary raiser other than hero; for hero-opened pots, the
  /// first 3-bettor). Null when no such villain exists.
  final String? openerPosGroup;

  /// Hero voluntarily put money in preflop (call/bet/raise, blinds
  /// excluded).
  final bool heroVpip;

  // Preflop
  final bool openedPot; // hero made the 1st voluntary raise
  final bool facedThreeBetAfterOpen;
  final bool foldedToThreeBet;
  final bool limped; // hero's 1st voluntary action = call with no raise before
  final bool limpFacedRaise; // limped, then a raise happened behind
  final bool limpFolded; // limped and folded to that raise
  final bool bbFacedSteal; // hero in BB facing a single steal-seat open
  final bool bbFoldedToSteal;

  // Postflop: per-street "hero faced a bet/raise" and his first response.
  // Response is one of 'fold' | 'call' | 'raise', null when never faced.
  final String? flopFacingResponse;
  final String? turnFacingResponse;
  final String? riverFacingResponse;

  // Showdown trio inputs
  final bool sawFlop;
  final bool wentToShowdown;
  final bool wonAtShowdown;
  final bool wonWithoutShowdown; // won after seeing flop, no showdown

  const LeakHandFacts({
    this.ref,
    this.flopTexture,
    this.posGroup,
    this.holeCards,
    this.flopStrength,
    this.netBB,
    this.stackBB,
    this.openerPosGroup,
    this.heroVpip = false,
    required this.isWalk,
    required this.openedPot,
    required this.facedThreeBetAfterOpen,
    required this.foldedToThreeBet,
    required this.limped,
    required this.limpFacedRaise,
    required this.limpFolded,
    required this.bbFacedSteal,
    required this.bbFoldedToSteal,
    required this.flopFacingResponse,
    required this.turnFacingResponse,
    required this.riverFacingResponse,
    required this.sawFlop,
    required this.wentToShowdown,
    required this.wonAtShowdown,
    required this.wonWithoutShowdown,
  });
}

class LeakExtractor {
  LeakExtractor._();

  static const _stealSeats = {'CO', 'BTN', 'SB'};

  /// Extract facts for the hero from one hand map. Returns null for hands
  /// that must not be analyzed (scouted records, missing hero seat).
  static LeakHandFacts? extract(Map<String, dynamic> hand, {String? ref}) {
    if (hand['isScouted'] == true) return null;
    final heroSeat = hand['heroSeatNumber'] as int?;
    if (heroSeat == null) return null;
    final actionsRaw = hand['actions'];
    if (actionsRaw is! List || actionsRaw.isEmpty) return null;
    final actions = actionsRaw
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .toList();

    final isWalk = StatsCalculator.isWalkHand(actions);

    // ── Preflop facts (reuse StatsCalculator where possible) ──────────
    final openedPot = _openedPot(actions, heroSeat);
    final facedThreeBet =
        openedPot && StatsCalculator.facedThreeBet(actions, heroSeat);
    final foldedToThreeBet =
        facedThreeBet && StatsCalculator.didFoldTo3Bet(actions, heroSeat);

    final limpFacts = _limpFacts(actions, heroSeat);
    final bbFacts = _bbStealFacts(actions, heroSeat);

    // ── Postflop facing responses ─────────────────────────────────────
    final flopResp = _facingResponse(actions, heroSeat, 'flop');
    final turnResp = _facingResponse(actions, heroSeat, 'turn');
    final riverResp = _facingResponse(actions, heroSeat, 'river');

    // ── Showdown trio ─────────────────────────────────────────────────
    final heroFoldedPreflop =
        StatsCalculator.playerFoldedPreflop(actions, heroSeat);
    final board = hand['boardCards'];
    final flopCards =
        board is Map && board['flop'] is List ? board['flop'] as List : null;
    final flopDealt = flopCards != null && flopCards.isNotEmpty;
    final sawFlop = !heroFoldedPreflop && flopDealt;
    final texture =
        flopDealt ? BoardTextureClassifier.classifyFlop(flopCards) : null;

    final heroFolded = actions.any((a) =>
        a['player'] == heroSeat && (a['action'] as String?) == 'fold');
    final reachedShowdown = hand['reachedShowdown'] == true;
    final wentToShowdown = sawFlop && reachedShowdown && !heroFolded;

    final won = _heroWon(hand, heroSeat);
    final wonAtShowdown = wentToShowdown && won;
    final wonWithoutShowdown = sawFlop && !reachedShowdown && won;

    final holeCardsRaw = hand['ourHoleCards'];
    String? holeCards;
    if (holeCardsRaw is Map) {
      final c1 = holeCardsRaw['card1'];
      final c2 = holeCardsRaw['card2'];
      if (c1 is String && c2 is String) holeCards = '$c1$c2';
    }

    return LeakHandFacts(
      ref: ref,
      flopTexture: texture,
      posGroup: _positionGroup(hand['heroPositionName'] as String?),
      holeCards: holeCards,
      flopStrength: flopDealt
          ? FlopStrengthClassifier.classify(holeCards, flopCards)
          : null,
      netBB: _netBB(hand, actions, heroSeat),
      stackBB: _stackBB(hand, actions, heroSeat),
      openerPosGroup: _openerPosGroup(actions, heroSeat),
      heroVpip: _heroVpip(actions, heroSeat),
      isWalk: isWalk,
      openedPot: openedPot,
      facedThreeBetAfterOpen: facedThreeBet,
      foldedToThreeBet: foldedToThreeBet,
      limped: limpFacts.$1,
      limpFacedRaise: limpFacts.$2,
      limpFolded: limpFacts.$3,
      bbFacedSteal: bbFacts.$1,
      bbFoldedToSteal: bbFacts.$2,
      flopFacingResponse: flopResp,
      turnFacingResponse: turnResp,
      riverFacingResponse: riverResp,
      sawFlop: sawFlop,
      wentToShowdown: wentToShowdown,
      wonAtShowdown: wonAtShowdown,
      wonWithoutShowdown: wonWithoutShowdown,
    );
  }

  /// Position → group. Mirrors RangeGridService.positionGroup — duplicated
  /// (10 lines) so this file stays Flutter-free for the CLI harness.
  static String? _positionGroup(String? position) {
    if (position == null || position.isEmpty) return null;
    final p = position.toUpperCase();
    if (p == 'BB') return 'BB';
    if (p == 'SB') return 'SB';
    if (p == 'BTN' || p == 'BU' || p == 'BTN/SB') return 'BTN';
    if (p == 'CO') return 'CO';
    if (p.startsWith('UTG')) return 'EP';
    return 'MP';
  }

  // ── Money reconstruction ───────────────────────────────────────────
  //
  // Amount semantics (CLAUDE.md "Action Amount Rules"): preflop raises
  // store the street TOTAL; postflop raises store the ADDITIONAL amount
  // on top of the current bet; calls store the actual amount put in;
  // blind posts store the posted amount. All-in is treated with its
  // street's raise semantics — a documented approximation.
  // Winnings: potAmount to the winner; chopped pots use the hero's
  // individual share when present. Side-pot overlays are approximated by
  // potAmount (documented limitation; affects multiway all-ins only).

  static double? _netBB(Map<String, dynamic> hand,
      List<Map<String, dynamic>> actions, int heroSeat) {
    final bigBlind = (hand['bigBlind'] as num?)?.toDouble();
    if (bigBlind == null || bigBlind <= 0) return null;
    final invested = _heroInvested(actions, heroSeat);
    double winnings = 0;
    if (_heroWon(hand, heroSeat)) {
      final pot = (hand['potAmount'] as num?)?.toDouble() ?? 0;
      if (hand['isChoppedPot'] == true) {
        final shares = hand['individualShares'];
        final share = shares is Map
            ? (shares['$heroSeat'] as num?)?.toDouble()
            : null;
        final perWinner = (hand['sharePerWinner'] as num?)?.toDouble();
        final winners = hand['choppedWinners'];
        winnings = share ??
            perWinner ??
            (winners is List && winners.isNotEmpty
                ? pot / winners.length
                : pot);
      } else {
        winnings = pot;
      }
    }
    return (winnings - invested) / bigBlind;
  }

  static double _heroInvested(
      List<Map<String, dynamic>> actions, int heroSeat) {
    var invested = 0.0;
    var street = 'preflop';
    var currentBet = 0.0; // highest street-total committed by anyone
    var heroStreetBet = 0.0;

    for (final a in actions) {
      final s = a['street'] as String? ?? 'preflop';
      if (s != street) {
        street = s;
        currentBet = 0;
        heroStreetBet = 0;
      }
      final type = a['action'] as String? ?? '';
      final amt = (a['amount'] as num?)?.toDouble();
      final isHero = a['player'] == heroSeat;

      if (StatsCalculator.isBlindAction(a)) {
        if (amt == null) continue;
        if (isHero) {
          invested += amt;
          heroStreetBet += amt;
        }
        if (amt > currentBet) currentBet = amt;
      } else if (type == 'call') {
        if (isHero && amt != null) {
          invested += amt;
          heroStreetBet += amt;
        }
      } else if (type == 'bet') {
        if (amt == null) continue;
        if (isHero) {
          final delta = amt - heroStreetBet;
          if (delta > 0) invested += delta;
          heroStreetBet = amt;
        }
        if (amt > currentBet) currentBet = amt;
      } else if (StatsCalculator.isRaiseAction(type)) {
        if (amt == null) continue;
        final newTotal = street == 'preflop' ? amt : currentBet + amt;
        if (isHero) {
          final delta = newTotal - heroStreetBet;
          if (delta > 0) invested += delta;
          heroStreetBet = newTotal;
        }
        if (newTotal > currentBet) currentBet = newTotal;
      }
    }
    return invested;
  }

  static double? _stackBB(Map<String, dynamic> hand,
      List<Map<String, dynamic>> actions, int heroSeat) {
    final bigBlind = (hand['bigBlind'] as num?)?.toDouble();
    if (bigBlind == null || bigBlind <= 0) return null;
    for (final a in actions) {
      if (a['player'] != heroSeat) continue;
      final stack = (a['playerStack'] as num?)?.toDouble();
      if (stack != null && stack > 0) return stack / bigBlind;
    }
    return null;
  }

  static bool _heroVpip(List<Map<String, dynamic>> actions, int heroSeat) {
    for (final a in actions) {
      if ((a['street'] as String? ?? 'preflop') != 'preflop') break;
      if (a['player'] != heroSeat) continue;
      if (StatsCalculator.isBlindAction(a)) continue;
      final type = a['action'] as String? ?? '';
      if (type == 'call' ||
          StatsCalculator.isBetAction(type) ||
          StatsCalculator.isRaiseAction(type)) {
        return true;
      }
    }
    return false;
  }

  /// First voluntary preflop raiser other than hero; when HERO opened, the
  /// first re-raiser instead. Null in unraised or hero-uncontested pots.
  static String? _openerPosGroup(
      List<Map<String, dynamic>> actions, int heroSeat) {
    for (final a in actions) {
      if ((a['street'] as String? ?? 'preflop') != 'preflop') break;
      if (StatsCalculator.isBlindAction(a)) continue;
      final type = a['action'] as String? ?? '';
      if (StatsCalculator.isRaiseAction(type) && a['player'] != heroSeat) {
        return _positionGroup(a['playerPosition'] as String?);
      }
    }
    return null;
  }

  static bool _heroWon(Map<String, dynamic> hand, int heroSeat) {
    if (hand['winnerId'] == heroSeat) return true;
    final chopped = hand['choppedWinners'];
    if (chopped is List && chopped.contains(heroSeat)) return true;
    return false;
  }

  /// Hero made the FIRST voluntary raise preflop (an open). Blinds are
  /// forced and do not count (see stats spec: 3-bet = 2nd voluntary raise).
  static bool _openedPot(List<Map<String, dynamic>> actions, int heroSeat) {
    for (final a in actions) {
      if ((a['street'] as String? ?? 'preflop') != 'preflop') break;
      if (StatsCalculator.isBlindAction(a)) continue;
      final type = a['action'] as String? ?? '';
      if (StatsCalculator.isRaiseAction(type)) {
        return a['player'] == heroSeat; // first voluntary raise
      }
    }
    return false;
  }

  /// (limped, limpFacedRaise, limpFolded): hero's first voluntary preflop
  /// action is a call while no voluntary raise happened yet (open-limp or
  /// over-limp; SB completing counts). BB checking is not a limp.
  static (bool, bool, bool) _limpFacts(
      List<Map<String, dynamic>> actions, int heroSeat) {
    var raiseSeen = false;
    var limped = false;
    var facedRaise = false;
    for (final a in actions) {
      if ((a['street'] as String? ?? 'preflop') != 'preflop') break;
      if (StatsCalculator.isBlindAction(a)) continue;
      final type = a['action'] as String? ?? '';
      final isHero = a['player'] == heroSeat;
      if (!limped) {
        if (isHero && type == 'call' && !raiseSeen) {
          limped = true;
          continue;
        }
        if (isHero && type != 'call') {
          // Hero's first voluntary action was not a limp — done.
          if (StatsCalculator.isRaiseAction(type) || type == 'fold') {
            return (false, false, false);
          }
        }
        if (StatsCalculator.isRaiseAction(type)) raiseSeen = true;
      } else {
        // After the limp: does a raise happen, and how does hero respond?
        if (StatsCalculator.isRaiseAction(type) && !isHero) {
          facedRaise = true;
        } else if (facedRaise && isHero) {
          return (true, true, type == 'fold');
        }
      }
    }
    return (limped, facedRaise, false);
  }

  /// (bbFacedSteal, bbFolded): hero in the BB facing exactly one voluntary
  /// raise from a steal seat (CO/BTN/SB), everyone else folded/called —
  /// hero's response recorded. Uses the position stored on the raise action.
  static (bool, bool) _bbStealFacts(
      List<Map<String, dynamic>> actions, int heroSeat) {
    if (StatsCalculator.findBigBlindSeat(actions) != heroSeat) {
      return (false, false);
    }
    var raiseCount = 0;
    String? raiserPos;
    for (final a in actions) {
      if ((a['street'] as String? ?? 'preflop') != 'preflop') break;
      if (StatsCalculator.isBlindAction(a)) continue;
      final type = a['action'] as String? ?? '';
      final isHero = a['player'] == heroSeat;
      if (StatsCalculator.isRaiseAction(type)) {
        raiseCount++;
        if (raiseCount > 1) return (false, false); // 3-bet pot, not a steal
        if (isHero) return (false, false);
        raiserPos = a['playerPosition'] as String?;
      } else if (isHero && raiseCount == 1) {
        if (raiserPos == null || !_stealSeats.contains(raiserPos)) {
          return (false, false);
        }
        return (true, type == 'fold');
      }
    }
    return (false, false);
  }

  /// Hero's first response when facing an outstanding bet/raise on
  /// [street]: 'fold' | 'call' | 'raise', or null if never faced one.
  /// All-in responses count as raises; an all-in call cannot be
  /// distinguished from amount alone in phase 1 and is counted as 'raise'
  /// only when typed as all-in, 'call' when typed as call.
  static String? _facingResponse(
      List<Map<String, dynamic>> actions, int heroSeat, String street) {
    var betOutstanding = false;
    for (final a in actions) {
      if ((a['street'] as String?) != street) continue;
      final type = a['action'] as String? ?? '';
      final isHero = a['player'] == heroSeat;
      if (isHero && betOutstanding) {
        if (type == 'fold') return 'fold';
        if (type == 'call') return 'call';
        if (StatsCalculator.isRaiseAction(type) ||
            StatsCalculator.isBetAction(type)) {
          return 'raise';
        }
        return null; // check against a bet shouldn't happen; bail safely
      }
      if (StatsCalculator.isBetAction(type) ||
          StatsCalculator.isRaiseAction(type)) {
        if (!isHero) betOutstanding = true;
      }
    }
    return null;
  }
}
