/// Factory methods for creating mock poker hand action data
/// used across all statistics detection tests.
class MockHandActions {
  /// Creates a basic action map
  static Map<String, dynamic> action({
    required int player,
    required String actionType,
    String street = 'preflop',
    double? amount,
    String? playerPosition,
    String? playerName,
  }) {
    return {
      'player': player,
      'action': actionType,
      'street': street,
      if (amount != null) 'amount': amount,
      if (playerPosition != null) 'playerPosition': playerPosition,
      if (playerName != null) 'playerName': playerName,
    };
  }

  /// Creates a small blind posting action
  static Map<String, dynamic> smallBlind(int player, double amount) {
    return action(player: player, actionType: 'small blind', amount: amount, playerPosition: 'SB');
  }

  /// Creates a big blind posting action
  static Map<String, dynamic> bigBlind(int player, double amount) {
    return action(player: player, actionType: 'big blind', amount: amount, playerPosition: 'BB');
  }

  /// Creates a fold action
  static Map<String, dynamic> fold(int player, {String street = 'preflop', String? position}) {
    return action(player: player, actionType: 'fold', street: street, playerPosition: position);
  }

  /// Creates a check action
  static Map<String, dynamic> check(int player, {String street = 'preflop', String? position}) {
    return action(player: player, actionType: 'check', street: street, playerPosition: position);
  }

  /// Creates a call action
  static Map<String, dynamic> call(int player, double amount, {String street = 'preflop', String? position}) {
    return action(player: player, actionType: 'call', amount: amount, street: street, playerPosition: position);
  }

  /// Creates a bet action
  static Map<String, dynamic> bet(int player, double amount, {String street = 'preflop', String? position}) {
    return action(player: player, actionType: 'bet', amount: amount, street: street, playerPosition: position);
  }

  /// Creates a raise action
  static Map<String, dynamic> raise(int player, double amount, {String street = 'preflop', String? position}) {
    return action(player: player, actionType: 'raise', amount: amount, street: street, playerPosition: position);
  }

  // ============================================
  // Pre-built scenario action lists
  // ============================================

  /// Standard preflop setup with blinds (SB=1, BB=2)
  static List<Map<String, dynamic>> blindsOnly({
    int sbPlayer = 1,
    int bbPlayer = 2,
    double sb = 1,
    double bb = 2,
  }) {
    return [
      smallBlind(sbPlayer, sb),
      bigBlind(bbPlayer, bb),
    ];
  }

  /// Walk hand - everyone folds to BB
  static List<Map<String, dynamic>> walkHand({int playerCount = 6}) {
    final actions = <Map<String, dynamic>>[
      smallBlind(1, 1),
      bigBlind(2, 2),
    ];
    // Players 3-6 fold
    for (int i = 3; i <= playerCount; i++) {
      actions.add(fold(i));
    }
    // SB folds
    actions.add(fold(1));
    return actions;
  }

  /// Standard 3-bet pot: P3 opens (1st), P4 raises (2nd), P5 3-bets (3rd)
  static List<Map<String, dynamic>> threeBetPot({
    int openerSeat = 3,
    int raiserSeat = 4,
    int threeBetterSeat = 5,
  }) {
    return [
      ...blindsOnly(),
      raise(openerSeat, 6.0, position: 'UTG'),
      raise(raiserSeat, 18.0, position: 'MP'),
      raise(threeBetterSeat, 50.0, position: 'CO'),
    ];
  }

  /// Hero faces 3-bet: P3 opens (1st), Hero raises (2nd), P3 3-bets (3rd)
  static List<Map<String, dynamic>> heroFaces3Bet({required int heroSeat}) {
    final villainSeat = heroSeat == 3 ? 4 : 3;
    return [
      ...blindsOnly(),
      raise(villainSeat, 6.0),   // 1st raise (open)
      raise(heroSeat, 18.0),    // 2nd raise (hero)
      raise(villainSeat, 50.0), // 3rd raise = 3-bet
    ];
  }

  /// Hero folds to 3-bet
  static List<Map<String, dynamic>> heroFoldsTo3Bet({required int heroSeat}) {
    final villainSeat = heroSeat == 3 ? 4 : 3;
    return [
      ...blindsOnly(),
      raise(villainSeat, 6.0),   // 1st raise
      raise(heroSeat, 18.0),    // 2nd raise
      raise(villainSeat, 50.0), // 3rd raise = 3-bet
      fold(heroSeat),            // Hero folds to 3-bet
    ];
  }

  /// Hero calls 3-bet
  static List<Map<String, dynamic>> heroCallsTo3Bet({required int heroSeat}) {
    final villainSeat = heroSeat == 3 ? 4 : 3;
    return [
      ...blindsOnly(),
      raise(villainSeat, 6.0),   // 1st raise
      raise(heroSeat, 18.0),    // 2nd raise
      raise(villainSeat, 50.0), // 3rd raise = 3-bet
      call(heroSeat, 32.0),     // Hero calls the 3-bet
    ];
  }

  /// C-bet opportunity: Hero raises pre, sees flop
  static List<Map<String, dynamic>> cbetOpportunity({required int heroSeat}) {
    return [
      ...blindsOnly(),
      raise(heroSeat, 6.0, position: 'BTN'),
      call(2, 4.0), // BB calls
      // Flop actions start
      check(2, street: 'flop'),
    ];
  }

  /// Hero c-bets: raises pre, bets flop
  static List<Map<String, dynamic>> heroCbets({required int heroSeat}) {
    return [
      ...blindsOnly(),
      raise(heroSeat, 6.0, position: 'BTN'),
      call(2, 4.0),
      check(2, street: 'flop'),
      bet(heroSeat, 8.0, street: 'flop'),
    ];
  }

  /// Hero checks flop (no c-bet)
  static List<Map<String, dynamic>> heroChecksFlopNoCbet({required int heroSeat}) {
    return [
      ...blindsOnly(),
      raise(heroSeat, 6.0, position: 'BTN'),
      call(2, 4.0),
      check(2, street: 'flop'),
      check(heroSeat, street: 'flop'),
    ];
  }

  /// Steal opportunity setup: all fold to hero in steal position
  static List<Map<String, dynamic>> stealOpportunity({
    required int heroSeat,
    required String position,
  }) {
    final actions = <Map<String, dynamic>>[
      smallBlind(1, 1),
      bigBlind(2, 2),
    ];
    // All fold before hero
    for (int i = 3; i < heroSeat; i++) {
      actions.add(fold(i, position: _positionForSeat(i, heroSeat)));
    }
    return actions;
  }

  /// Hero steals: raises from steal position with unopened pot
  static List<Map<String, dynamic>> heroSteals({
    required int heroSeat,
    required String position,
  }) {
    final actions = stealOpportunity(heroSeat: heroSeat, position: position);
    actions.add(raise(heroSeat, 5.0, position: position));
    return actions;
  }

  /// Check-raise opportunity on flop: hero checks, villain bets
  static List<Map<String, dynamic>> checkRaiseOpportunity({required int heroSeat}) {
    final villainSeat = heroSeat == 3 ? 4 : 3;
    return [
      ...blindsOnly(),
      raise(villainSeat, 6.0),
      call(heroSeat, 4.0),
      // Flop
      check(heroSeat, street: 'flop'),
      bet(villainSeat, 8.0, street: 'flop'),
    ];
  }

  /// Hero check-raises on flop
  static List<Map<String, dynamic>> heroCheckRaises({required int heroSeat}) {
    final villainSeat = heroSeat == 3 ? 4 : 3;
    return [
      ...blindsOnly(),
      raise(villainSeat, 6.0),
      call(heroSeat, 4.0),
      // Flop
      check(heroSeat, street: 'flop'),
      bet(villainSeat, 8.0, street: 'flop'),
      raise(heroSeat, 24.0, street: 'flop'),
    ];
  }

  /// Hero calls on flop (no check-raise)
  static List<Map<String, dynamic>> heroCallsFlop({required int heroSeat}) {
    final villainSeat = heroSeat == 3 ? 4 : 3;
    return [
      ...blindsOnly(),
      raise(villainSeat, 6.0),
      call(heroSeat, 4.0),
      // Flop
      check(heroSeat, street: 'flop'),
      bet(villainSeat, 8.0, street: 'flop'),
      call(heroSeat, 8.0, street: 'flop'),
    ];
  }

  static String _positionForSeat(int seat, int heroSeat) {
    // Simplified position mapping for tests
    if (seat == 3) return 'UTG';
    if (seat == 4) return 'MP';
    if (seat == 5) return 'CO';
    if (seat == 6) return 'BTN';
    return 'MP';
  }
}
