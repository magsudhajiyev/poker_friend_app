import 'package:poker_logger/models/hand_state_machine.dart';

/// Compact hand-map builder for Package F tests.
Map<String, dynamic> act(int player, String action, String street) =>
    {'player': player, 'action': action, 'street': street};

Map<String, dynamic> handMap(
  List<Map<String, dynamic>> actions, {
  int hero = 1,
  String pos = 'BTN',
  double pot = 20,
  String? completeness,
  bool scouted = false,
}) =>
    {
      'actions': actions,
      'heroSeatNumber': hero,
      'heroPositionName': pos,
      'potAmount': pot,
      'isScouted': scouted,
      if (completeness != null) 'completeness': completeness,
    };

/// Seat 1 opens, seat 3 calls, seat 1 c-bets, seat 3 folds (or calls).
Map<String, dynamic> cbetHand({bool fold = true, int hero = 1, double pot = 20}) =>
    handMap([
      act(1, 'raise', 'preflop'),
      act(3, 'call', 'preflop'),
      act(1, 'bet', 'flop'),
      act(3, fold ? 'fold' : 'call', 'flop'),
    ], hero: hero, pot: pot);

HandRecord record(Map<String, dynamic> m) {
  final acts = [
    for (final a in m['actions'] as List)
      {
        ...(a as Map<String, dynamic>),
        'timestamp': DateTime(2026).toIso8601String(),
        'buttonPosition': 1,
      }
  ];
  return HandRecord.fromMap({
    ...m,
    'actions': acts,
    'startTime': DateTime(2026).toIso8601String(),
    'handNumber': 1,
    'buttonPosition': 1,
    'playerCount': 6,
  });
}
