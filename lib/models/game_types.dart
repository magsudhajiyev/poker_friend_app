enum GameType {
  cash,
  tournament
}

extension GameTypeExtension on GameType {
  String get displayName {
    switch (this) {
      case GameType.cash:
        return 'Cash Game';
      case GameType.tournament:
        return 'MTT (Tournament)';
    }
  }
  
  String get shortName {
    switch (this) {
      case GameType.cash:
        return 'Cash';
      case GameType.tournament:
        return 'MTT';
    }
  }
  
  String get value {
    switch (this) {
      case GameType.cash:
        return 'cash';
      case GameType.tournament:
        return 'tournament';
    }
  }
  
  static GameType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'tournament':
      case 'mtt':
        return GameType.tournament;
      case 'cash':
      default:
        return GameType.cash;
    }
  }
}