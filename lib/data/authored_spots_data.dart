// EMBEDDED AUTHORED SPOTS (sourced from a solver export).
//
// Source spot: MTT 70bb · LJ opens 2.1 → BTN 3-bets to 7.35 → LJ calls →
// Flop T♠ 9♣ 4♦ → LJ checks → BTN bets 51% → LJ check-raises → BTN folds.
// Export: Google Sheet "MTT 70bb · LJ vs BTN · Ts9c4d" (2026-10-21,
// v2 — FULL 5-way strategy split raise/call/check/fold/allin per hand).
//
// The export gives RANGES, not a hero hand — so we mint one spot per holding
// that stays in LJ's range through both decisions and makes a sensible
// check-raise on T94. Each action's grid is the solver's exact per-hand
// frequency for that action; the grader reads the hero hand's share directly.
import '../models/authored_spot.dart';

// ── Decision 1: preflop, LJ faces BTN's 3-bet. Best = CALL. ──────────────────
// Full 5-way split: 4-bet (raise), call, fold, and the AKo-style jams (allin).
const Map<String, double> _d1Raise = {'AA': 1.0, 'AKs': 1.0, 'ATs': 0.32, 'A9s': 0.464, 'A8s': 0.319, 'A7s': 0.549, 'A6s': 0.004, 'A5s': 0.486, 'A4s': 0.288, 'A3s': 0.001, 'AKo': 0.255, 'KK': 1.0, 'KJs': 0.087, 'KTs': 0.479, 'K9s': 0.121, 'AQo': 0.54, 'KQo': 0.063, 'QQ': 0.829, 'QJs': 0.008, 'QTs': 0.183, 'AJo': 0.161, 'JJ': 0.275, 'JTs': 0.187, 'TT': 0.319, 'T9s': 0.108, '99': 0.17};
const Map<String, double> _d1Call = {'AQs': 1.0, 'AJs': 1.0, 'ATs': 0.68, 'A9s': 0.536, 'A8s': 0.681, 'A7s': 0.278, 'A5s': 0.514, 'A4s': 0.711, 'A3s': 0.948, 'AKo': 0.024, 'KQs': 1.0, 'KJs': 0.913, 'KTs': 0.521, 'K9s': 0.632, 'K8s': 0.053, 'AQo': 0.46, 'KQo': 0.348, 'QQ': 0.154, 'QJs': 0.992, 'QTs': 0.817, 'AJo': 0.029, 'JJ': 0.515, 'JTs': 0.813, 'J9s': 0.331, 'TT': 0.681, 'T9s': 0.892, 'T8s': 0.069, '99': 0.83, '98s': 0.788};
const Map<String, double> _d1Fold = {'A7s': 0.173, 'A6s': 0.996, 'A3s': 0.051, 'A2s': 1.0, 'K9s': 0.247, 'K8s': 0.947, 'K7s': 1.0, 'K6s': 1.0, 'K5s': 1.0, 'KQo': 0.589, 'Q9s': 1.0, 'Q8s': 1.0, 'AJo': 0.81, 'KJo': 1.0, 'QJo': 1.0, 'J9s': 0.668, 'J8s': 1.0, 'ATo': 1.0, 'KTo': 1.0, 'QTo': 1.0, 'JTo': 1.0, 'T8s': 0.931, 'A9o': 1.0, '98s': 0.212};
const Map<String, double> _d1Allin = {'AKo': 0.721, 'QQ': 0.017, 'JJ': 0.21};

// ── Decision 2: flop T94, LJ faces BTN's 51% bet. Best = RAISE (check-raise). ─
// Full split: check-raise (raise), call, fold.
const Map<String, double> _d2Raise = {'AQs': 0.246, 'AJs': 0.462, 'ATs': 0.16, 'A8s': 0.001, 'KQs': 0.943, 'KJs': 0.235, 'KTs': 0.34, 'K9s': 0.005, 'AQo': 0.049, 'KQo': 0.589, 'QQ': 1.0, 'QJs': 0.45, 'QTs': 0.393, 'JJ': 0.999, 'JTs': 0.667, 'J9s': 0.268, 'TT': 0.763, 'T9s': 0.5, 'T8s': 0.636, '99': 0.875, '98s': 0.232, '88': 0.295, '87s': 0.002, '77': 0.003, '76s': 0.225, '44': 0.625};
const Map<String, double> _d2Call = {'AQs': 0.506, 'AJs': 0.001, 'ATs': 0.84, 'A9s': 1.0, 'A4s': 1.0, 'AKo': 0.999, 'KQs': 0.057, 'KJs': 0.764, 'KTs': 0.66, 'K9s': 0.995, 'KQo': 0.41, 'QJs': 0.55, 'QTs': 0.607, 'JJ': 0.001, 'JTs': 0.333, 'J9s': 0.732, 'TT': 0.237, 'T9s': 0.5, 'T8s': 0.364, '99': 0.125, '98s': 0.768, '88': 0.41, '87s': 0.998, '77': 0.193, '76s': 0.526, '54s': 1.0, '44': 0.375};
const Map<String, double> _d2Fold = {'AQs': 0.248, 'AJs': 0.537, 'A8s': 0.999, 'A7s': 1.0, 'A5s': 1.0, 'A3s': 1.0, 'AKo': 0.001, 'K8s': 1.0, 'AQo': 0.951, 'KQo': 0.001, 'AJo': 1.0, '88': 0.295, '77': 0.805, '76s': 0.25, '66': 0.999, '65s': 1.0, '55': 1.0, '33': 1.0};

/// Decision 1 — preflop vs the 3-bet. The hero's realistic buttons are
/// fold/call/raise (4-bet); all-in exists in the grid for the range view.
AuthoredDecision _decision1() => AuthoredDecision(
      street: AuthoredStreet.preflop,
      board: const [],
      prompt: '',
      options: const [
        AuthoredAction.fold,
        AuthoredAction.call,
        AuthoredAction.raise,
      ],
      best: AuthoredAction.call,
      potBB: 11.45,
      toCallBB: 5.25,
      raiseToBB: 16.17, // solver 4-bet sizing
      heroChipBB: 2.1,
      heroTag: 'Open',
      villainBetBB: 7.35,
      villainTag: '3-bet',
      freq: {
        AuthoredAction.raise: Map<String, double>.from(_d1Raise),
        AuthoredAction.call: Map<String, double>.from(_d1Call),
        AuthoredAction.fold: Map<String, double>.from(_d1Fold),
        AuthoredAction.allin: Map<String, double>.from(_d1Allin),
      },
    );

/// Decision 2 — flop T♠9♣4♦, check-raise vs the 51% c-bet.
AuthoredDecision _decision2() => AuthoredDecision(
      street: AuthoredStreet.flop,
      board: const ['10♠', '9♣', '4♦'],
      prompt: '', // chips/tags replace the floating text
      options: const [
        AuthoredAction.fold,
        AuthoredAction.call,
        AuthoredAction.raise,
      ],
      best: AuthoredAction.raise,
      potBB: 15.7, // ~2 x 7.35 + blinds
      toCallBB: 8.0, // ~51% of pot
      raiseToBB: 18.0, // check-raise to ~30% geometric sizing
      heroTag: 'Check', // hero checked to the c-bet
      villainBetBB: 8.0, // BTN's 51% c-bet chip
      villainTag: 'Bet 51%',
      freq: {
        AuthoredAction.raise: Map<String, double>.from(_d2Raise),
        AuthoredAction.call: Map<String, double>.from(_d2Call),
        AuthoredAction.fold: Map<String, double>.from(_d2Fold),
      },
    );

/// Hero-hand variants from this ONE solved hand. Each is a full spot.
/// 99 ships today; TT/KQs/JTs are kept for future daily challenges.
const Map<String, List<String>> _heroCardsByClass = {
  '99': ['9♠', '9♥'], // set of nines on T94 — the clean value check-raise
  'TT': ['10♥', '10♦'], // top set
  'KQs': ['K♠', 'Q♠'], // overcards + gutshot — the bluff side (94% CR)
  'JTs': ['J♦', '10♦'], // pair + open-ender
};

AuthoredSpot _spotForHand(String handClass) => AuthoredSpot(
      id: 'lj-btn-ts9c4d-${handClass.toLowerCase()}',
      title: 'MTT 70bb · LJ vs BTN · T94 two-tone',
      formatLabel: 'MTT · 70bb · 9-max',
      stackBB: 70,
      anteMode: true,
      heroPosition: 'LJ',
      heroCards: _heroCardsByClass[handClass]!,
      heroHandClass: handClass,
      villainPosition: 'BTN',
      decisions: [_decision1(), _decision2()],
    );

/// The spot served for TODAY's challenge on-device test: hero holds 99.
final AuthoredSpot todayAuthoredSpot = _spotForHand('99');

/// All minted variants (for future daily rotations).
final List<AuthoredSpot> authoredSpotVariants = [
  for (final h in _heroCardsByClass.keys) _spotForHand(h),
];

/// Which authored spot (if any) the given challenge day should serve.
///
/// TEMPORARY for the first on-device test: always returns today's 99 spot so
/// it can be played now. Once a proper per-day schedule exists, map specific
/// day keys → spots (or pull from Firestore `authored_spots`).
AuthoredSpot? authoredSpotForToday(DateTime day) => todayAuthoredSpot;
