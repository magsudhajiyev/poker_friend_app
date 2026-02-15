/// Account type determines what features and screens are available to the user
enum AccountType {
  player,   // Regular player - default
  dealer,   // Dealer - can log hands for tables
  admin,    // Admin - can create clubs, manage dealers
}

extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.player:
        return 'Player';
      case AccountType.dealer:
        return 'Dealer';
      case AccountType.admin:
        return 'Admin';
    }
  }

  String get value {
    switch (this) {
      case AccountType.player:
        return 'player';
      case AccountType.dealer:
        return 'dealer';
      case AccountType.admin:
        return 'admin';
    }
  }

  static AccountType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'dealer':
        return AccountType.dealer;
      case 'admin':
        return AccountType.admin;
      case 'player':
      default:
        return AccountType.player;
    }
  }
}
