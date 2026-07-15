enum SymbolPosition { prefix, suffix }

class Currency {
  final String code;
  final String symbol;
  final String name;
  final String flag;

  /// Optional SVG flag asset — rendered by UI in preference to the emoji
  /// `flag` glyph when set. Currencies without a matching asset in
  /// `assets/icons/Property 1=*.svg` fall back to the emoji.
  final String? flagAsset;
  final int decimalPlaces;
  final SymbolPosition position;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
    this.flagAsset,
    this.decimalPlaces = 2,
    this.position = SymbolPosition.prefix,
  });

  static const List<Currency> all = [
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸', flagAsset: 'assets/icons/flags/Property 1=United States of America (US).svg'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺', flagAsset: 'assets/icons/flags/Property 1=Europe.svg'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound', flag: '🇬🇧', flagAsset: 'assets/icons/flags/Property 1=United Kingdom.svg'),
    Currency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', flag: '🇨🇦', flagAsset: 'assets/icons/flags/Property 1=Canada.svg'),
    Currency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: '🇦🇺', flagAsset: 'assets/icons/flags/Property 1=Australia.svg'),
    Currency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', flag: '🇧🇷', flagAsset: 'assets/icons/flags/Property 1=Brasil.svg'),
    Currency(code: 'PLN', symbol: 'zł', name: 'Polish Zloty', flag: '🇵🇱', flagAsset: 'assets/icons/flags/Property 1=Poland (PL).svg', position: SymbolPosition.suffix),
    Currency(code: 'RUB', symbol: '₽', name: 'Russian Ruble', flag: '🇷🇺', flagAsset: 'assets/icons/flags/Property 1=Russia (RU).svg', position: SymbolPosition.suffix),
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee', flag: '🇮🇳', flagAsset: 'assets/icons/flags/Property 1=India.svg'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen', flag: '🇯🇵', flagAsset: 'assets/icons/flags/Property 1=Japan.svg', decimalPlaces: 0),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', flag: '🇨🇳', flagAsset: 'assets/icons/flags/Property 1=China.svg'),
    Currency(code: 'KRW', symbol: '₩', name: 'Korean Won', flag: '🇰🇷', flagAsset: 'assets/icons/flags/Property 1=Korea.svg', decimalPlaces: 0),
    Currency(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', flag: '🇸🇪', flagAsset: 'assets/icons/flags/Property 1=Sweden.svg', position: SymbolPosition.suffix),
    Currency(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso', flag: '🇲🇽', flagAsset: 'assets/icons/flags/Property 1=Mexico.svg'),
    Currency(code: 'TRY', symbol: '₺', name: 'Turkish Lira', flag: '🇹🇷', flagAsset: 'assets/icons/flags/Property 1=Turkey.svg', position: SymbolPosition.suffix),
    Currency(code: 'CZK', symbol: 'Kč', name: 'Czech Koruna', flag: '🇨🇿', flagAsset: 'assets/icons/flags/Property 1=Czech Republic.svg', decimalPlaces: 0, position: SymbolPosition.suffix),
    Currency(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', flag: '🇳🇴', flagAsset: 'assets/icons/flags/Property 1=Norway.svg', position: SymbolPosition.suffix),
    Currency(code: 'DKK', symbol: 'kr', name: 'Danish Krone', flag: '🇩🇰', flagAsset: 'assets/icons/flags/Property 1=Denmark.svg', position: SymbolPosition.suffix),
    Currency(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', flag: '🇨🇭', flagAsset: 'assets/icons/flags/Property 1=Switzerland.svg', position: SymbolPosition.suffix),
    Currency(code: 'ILS', symbol: '₪', name: 'Israeli Shekel', flag: '🇮🇱', flagAsset: 'assets/icons/flags/Property 1=Israli.svg'),
    Currency(code: 'UAH', symbol: '₴', name: 'Ukrainian Hryvnia', flag: '🇺🇦', flagAsset: 'assets/icons/flags/Property 1=ukraine.svg'),
    Currency(code: 'ARS', symbol: 'ARS', name: 'Argentine Peso', flag: '🇦🇷', flagAsset: 'assets/icons/flags/Property 1=Argentina.svg', decimalPlaces: 0),
  ];

  static Currency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => all.first, // USD fallback
    );
  }
}
