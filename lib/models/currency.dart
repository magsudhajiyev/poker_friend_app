enum SymbolPosition { prefix, suffix }

class Currency {
  final String code;
  final String symbol;
  final String name;
  final String flag;
  final int decimalPlaces;
  final SymbolPosition position;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
    this.decimalPlaces = 2,
    this.position = SymbolPosition.prefix,
  });

  static const List<Currency> all = [
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound', flag: '🇬🇧'),
    Currency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', flag: '🇨🇦'),
    Currency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: '🇦🇺'),
    Currency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', flag: '🇧🇷'),
    Currency(code: 'PLN', symbol: 'zł', name: 'Polish Zloty', flag: '🇵🇱', position: SymbolPosition.suffix),
    Currency(code: 'RUB', symbol: '₽', name: 'Russian Ruble', flag: '🇷🇺', position: SymbolPosition.suffix),
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee', flag: '🇮🇳'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen', flag: '🇯🇵', decimalPlaces: 0),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', flag: '🇨🇳'),
    Currency(code: 'KRW', symbol: '₩', name: 'Korean Won', flag: '🇰🇷', decimalPlaces: 0),
    Currency(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', flag: '🇸🇪', position: SymbolPosition.suffix),
    Currency(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso', flag: '🇲🇽'),
    Currency(code: 'TRY', symbol: '₺', name: 'Turkish Lira', flag: '🇹🇷', position: SymbolPosition.suffix),
    Currency(code: 'CZK', symbol: 'Kč', name: 'Czech Koruna', flag: '🇨🇿', decimalPlaces: 0, position: SymbolPosition.suffix),
  ];

  static Currency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => all.first, // USD fallback
    );
  }
}
