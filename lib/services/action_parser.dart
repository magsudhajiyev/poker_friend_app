/// Detected poker action from speech.
class ParsedAction {
  final String action;
  final double? amount;
  final double confidence;

  ParsedAction({
    required this.action,
    this.amount,
    this.confidence = 1.0,
  });

  @override
  String toString() => 'ParsedAction($action${amount != null ? ', $amount' : ''})';
}

/// Local action parser for poker speech.
///
/// Parses transcriptions into poker actions.
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

  // Patterns with their action types and amount group index
  static final List<_ActionPattern> _patterns = [
    // Fold
    _ActionPattern(RegExp(r'\b(fold|pass|muck)\b', caseSensitive: false), 'fold'),

    // Check
    _ActionPattern(RegExp(r'\b(check|checking)\b', caseSensitive: false), 'check'),

    // Call
    _ActionPattern(RegExp(r'\b(call|calling)\b', caseSensitive: false), 'call'),

    // Bet with amount (supports commas, decimals, and "k" suffix: 2,000 or 9.5k)
    // Allows punctuation between action and amount (e.g., "bet. 500" or "bet 500")
    _ActionPattern(
      RegExp(r'\b(?:bet|betting)[.,\s]+([\d,]+\.?\d*k?)', caseSensitive: false),
      'bet',
      amountGroup: 1,
    ),

    // Raise with amount (supports commas, decimals, and "k" suffix: 2,000 or 9.5k)
    // Allows punctuation between action and amount (e.g., "raise. 3,000" or "raise 3000")
    _ActionPattern(
      RegExp(r'\b(?:raise|re-raise|reraise|raising)[.,\s]+([\d,]+\.?\d*k?)', caseSensitive: false),
      'raise',
      amountGroup: 1,
    ),

    // Raise without amount (only matches if NOT followed by punctuation+number)
    _ActionPattern(
      RegExp(r'\b(raise|re-raise|reraise)\b(?![.,\s]+[\d,])', caseSensitive: false),
      'raise',
    ),

    // All-in
    _ActionPattern(
      RegExp(r'\b(all-in|all in|allin|shove|jam)\b', caseSensitive: false),
      'all-in',
    ),
  ];

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

  /// Parse a transcript into a list of poker actions.
  ///
  /// Returns actions in the order they appear in the transcript.
  static List<ParsedAction> parse(String transcript) {
    final actions = <ParsedAction>[];
    final text = _normalizeNumbers(transcript.toLowerCase());

    // Track matches with their positions to sort by order of appearance
    final matches = <_MatchedAction>[];

    for (final pattern in _patterns) {
      for (final match in pattern.regex.allMatches(text)) {
        double? amount;

        // Extract amount if pattern has an amount group
        if (pattern.amountGroup != null && match.groupCount >= pattern.amountGroup!) {
          final amountStr = match.group(pattern.amountGroup!);
          amount = _parseAmount(amountStr);
        }

        matches.add(_MatchedAction(
          position: match.start,
          action: pattern.action,
          amount: amount,
        ));
      }
    }

    // Sort by position to maintain order of actions
    matches.sort((a, b) => a.position.compareTo(b.position));

    // Remove duplicates at same position (e.g., "raise" matching both with and without amount)
    final seen = <int>{};
    for (final match in matches) {
      if (!seen.contains(match.position)) {
        seen.add(match.position);
        actions.add(ParsedAction(
          action: match.action,
          amount: match.amount,
        ));
      }
    }

    return actions;
  }
}

class _ActionPattern {
  final RegExp regex;
  final String action;
  final int? amountGroup;

  _ActionPattern(this.regex, this.action, {this.amountGroup});
}

class _MatchedAction {
  final int position;
  final String action;
  final double? amount;

  _MatchedAction({
    required this.position,
    required this.action,
    this.amount,
  });
}
