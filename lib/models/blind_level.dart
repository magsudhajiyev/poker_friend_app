import 'game_types.dart';

/// One selectable small/big blind pair on the "Log a hand" blinds wheel.
/// [custom] is the trailing "Custom…" entry (opens the blinds editor).
class BlindLevel {
  final double sb;
  final double bb;
  final bool isCustom;

  const BlindLevel(this.sb, this.bb) : isCustom = false;
  const BlindLevel._custom()
      : sb = 0,
        bb = 0,
        isCustom = true;

  static const BlindLevel custom = BlindLevel._custom();

  static const List<BlindLevel> cash = [
    BlindLevel(0.05, 0.10),
    BlindLevel(0.10, 0.20),
    BlindLevel(0.10, 0.25),
    BlindLevel(0.25, 0.50),
    BlindLevel(0.50, 1),
    BlindLevel(1, 2),
    BlindLevel(1, 3),
    BlindLevel(2, 3),
    BlindLevel(2, 5),
    BlindLevel(5, 5),
    BlindLevel(5, 10),
    BlindLevel(10, 20),
    BlindLevel(10, 25),
    BlindLevel(25, 50),
    BlindLevel(50, 100),
    BlindLevel(100, 200),
  ];

  static const List<BlindLevel> tournament = [
    BlindLevel(25, 50),
    BlindLevel(50, 100),
    BlindLevel(75, 150),
    BlindLevel(100, 200),
    BlindLevel(150, 300),
    BlindLevel(200, 400),
    BlindLevel(250, 500),
    BlindLevel(300, 600),
    BlindLevel(400, 800),
    BlindLevel(500, 1000),
    BlindLevel(600, 1200),
    BlindLevel(800, 1600),
    BlindLevel(1000, 2000),
    BlindLevel(1500, 3000),
    BlindLevel(2000, 4000),
    BlindLevel(3000, 6000),
    BlindLevel(5000, 10000),
    BlindLevel(10000, 20000),
  ];

  static const BlindLevel defaultCash = BlindLevel(1, 2);
  static const BlindLevel defaultTournament = BlindLevel(100, 200);

  static List<BlindLevel> baseFor(GameType t) =>
      t == GameType.cash ? cash : tournament;

  static BlindLevel defaultFor(GameType t) =>
      t == GameType.cash ? defaultCash : defaultTournament;

  /// [base] plus [extras] (custom / remembered levels), sorted by big blind
  /// then small blind, de-duplicated, with the "Custom…" entry last.
  static List<BlindLevel> merged(
      List<BlindLevel> base, Iterable<BlindLevel> extras) {
    final all = {...base, ...extras}.toList()
      ..sort((a, b) {
        final c = a.bb.compareTo(b.bb);
        return c != 0 ? c : a.sb.compareTo(b.sb);
      });
    return [...all, custom];
  }

  @override
  bool operator ==(Object o) =>
      o is BlindLevel && o.sb == sb && o.bb == bb && o.isCustom == isCustom;

  @override
  int get hashCode => Object.hash(sb, bb, isCustom);
}
