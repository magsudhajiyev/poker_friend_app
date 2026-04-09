/// Detected poker action from speech.
class ParsedAction {
  final String action;
  final double? amount;
  final double confidence;
  final int? seatNumber;

  const ParsedAction({
    required this.action,
    this.amount,
    this.confidence = 1.0,
    this.seatNumber,
  });

  @override
  String toString() =>
      'ParsedAction(seat=$seatNumber, $action${amount != null ? ', $amount' : ''})';
}

/// Local action parser for seat-anchored poker speech.
///
/// Parses transcriptions into poker actions with required seat numbers.
/// Expected format: "seat 4 call", "s4 call", "4 call", "seat 3 raise 2000"
/// Expects English input (Soniox translates all languages to English).
class ActionParser {
  // English and Polish number words to digits
  static const Map<String, String> _numberWords = {
    // English
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
    'eleven': '11', 'twelve': '12', 'thirteen': '13', 'fourteen': '14',
    'fifteen': '15', 'sixteen': '16', 'seventeen': '17', 'eighteen': '18',
    'nineteen': '19', 'twenty': '20', 'thirty': '30', 'forty': '40',
    'fifty': '50', 'sixty': '60', 'seventy': '70', 'eighty': '80',
    'ninety': '90', 'hundred': '100', 'thousand': '1000',

    // Polish
    'jeden': '1', 'dwa': '2', 'trzy': '3', 'cztery': '4', 'pięć': '5',
    'sześć': '6', 'siedem': '7', 'osiem': '8', 'dziewięć': '9', 'dziesięć': '10',
    'jedenaście': '11', 'dwanaście': '12', 'trzynaście': '13', 'czternaście': '14',
    'piętnaście': '15', 'szesnaście': '16', 'siedemnaście': '17', 'osiemnaście': '18',
    'dziewiętnaście': '19', 'dwadzieścia': '20', 'trzydzieści': '30',
    'czterdzieści': '40', 'pięćdziesiąt': '50', 'sześćdziesiąt': '60',
    'siedemdziesiąt': '70', 'osiemdziesiąt': '80', 'dziewięćdziesiąt': '90',
    'sto': '100', 'tysiąc': '1000',
  };

  /// Single unified pattern for seat-anchored commands.
  /// Matches: "seat 4 call", "s4 call", "4 call", "seat 3 raise 2000"
  ///
  /// Groups: (1)=seat number, (2)=action keyword, (3)=optional amount
  ///
  /// NOTE: "all-in" uses \b anchor to prevent "call" from matching as c-"all in".
  /// Actions are listed longest-first to prevent partial matches.
  static final RegExp _seatActionPattern = RegExp(
    r'(?:seat\s+|s)(\d)[,.\s]+'       // "seat 4 " or "s4, " with seat in group(1)
    r'(all[\s-]?in|re-?raise|reraise|raising|checking|calling|betting|'
    r'fold|pass|muck|check|call|bet|raise|shove|jam)'  // action in group(2)
    r'(?:[.,\s]+([\d,]+\.?\d*k?))?',   // optional amount in group(3)
    caseSensitive: false,
  );

  /// Bare digit prefix: "4 call", "5 fold"
  /// Only matches digits 1-9 preceded by start-of-string or separator.
  static final RegExp _bareSeatPattern = RegExp(
    r'(?:^|[.\s,])([1-9])[,.\s]+'     // seat digit in group(1)
    r'(all[\s-]?in|re-?raise|reraise|raising|checking|calling|betting|'
    r'fold|pass|muck|check|call|bet|raise|shove|jam)'  // action in group(2)
    r'(?:[.,\s]+([\d,]+\.?\d*k?))?',   // optional amount in group(3)
    caseSensitive: false,
  );

  /// Convert number words to digits (e.g., "five" → "5").
  /// Sorts by word length descending so "sixty" is replaced before "six".
  static String _normalizeNumbers(String text) {
    var result = text;

    // Sort by length descending so longer words are replaced first
    // This prevents "sixty" becoming "6ty" when "six" is replaced first
    final sortedWords = _numberWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sortedWords) {
      result = result.replaceAll(word, _numberWords[word]!);
    }
    return result;
  }

  /// Parse amount string handling commas and "k" suffix.
  /// Examples: "2,000" → 2000.0, "9.5k" → 9500.0, "500" → 500.0
  static double? _parseAmount(String? amountStr) {
    if (amountStr == null || amountStr.isEmpty) return null;

    var cleaned = amountStr.toLowerCase().trim();

    // Handle "k" suffix (e.g., "9.5k" → 9500)
    if (cleaned.endsWith('k')) {
      final numStr = cleaned.substring(0, cleaned.length - 1).replaceAll(',', '');
      final num = double.tryParse(numStr);
      if (num != null) return num * 1000;
      return null;
    }

    // Remove commas and parse (e.g., "2,000" → 2000)
    cleaned = cleaned.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  /// Normalize action keywords to canonical form.
  static String _normalizeAction(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'pass' || lower == 'muck') return 'fold';
    if (lower == 'checking') return 'check';
    if (lower == 'calling') return 'call';
    if (lower == 'betting') return 'bet';
    if (lower.startsWith('re') || lower == 'raising') return 'raise';
    if (lower.startsWith('all') || lower == 'shove' || lower == 'jam') {
      return 'all-in';
    }
    return lower;
  }

  /// Parse a transcript into a list of seat-anchored poker actions.
  ///
  /// Returns actions in the order they appear in the transcript.
  /// Actions without a seat prefix are returned with seatNumber=null
  /// so the validator can reject them with a clear message.
  static List<ParsedAction> parse(String transcript) {
    final text = _normalizeNumbers(transcript.toLowerCase());
    final matches = <_MatchedAction>[];

    // Track consumed character ranges to prevent duplicate matches
    final consumed = <int>{};

    // 1. Match "seat N action" and "sN action" patterns (higher priority)
    for (final match in _seatActionPattern.allMatches(text)) {
      final seat = int.tryParse(match.group(1)!);
      if (seat == null || seat < 1 || seat > 9) continue;

      final action = _normalizeAction(match.group(2)!);
      final amount = _parseAmount(match.group(3));

      matches.add(_MatchedAction(
        position: match.start,
        action: action,
        amount: amount,
        seatNumber: seat,
      ));

      // Mark range as consumed
      for (int i = match.start; i < match.end; i++) {
        consumed.add(i);
      }
    }

    // 2. Match bare "N action" patterns — skip if already consumed
    for (final match in _bareSeatPattern.allMatches(text)) {
      // Skip if any character in this match was already consumed
      bool overlaps = false;
      for (int i = match.start; i < match.end; i++) {
        if (consumed.contains(i)) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;

      final seat = int.tryParse(match.group(1)!);
      if (seat == null) continue;

      final action = _normalizeAction(match.group(2)!);
      final amount = _parseAmount(match.group(3));

      matches.add(_MatchedAction(
        position: match.start,
        action: action,
        amount: amount,
        seatNumber: seat,
      ));
    }

    // 3. Sort by position to maintain order
    matches.sort((a, b) => a.position.compareTo(b.position));

    return matches
        .map((m) => ParsedAction(
              action: m.action,
              amount: m.amount,
              seatNumber: m.seatNumber,
            ))
        .toList();
  }
}

class _MatchedAction {
  final int position;
  final String action;
  final double? amount;
  final int? seatNumber;

  _MatchedAction({
    required this.position,
    required this.action,
    this.amount,
    this.seatNumber,
  });
}
