import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

/// Parsed poker action from speech
class DetectedPokerAction {
  final String action;      // fold, check, call, bet, raise, all-in
  final double? amount;     // Amount for bet/raise
  final double confidence;  // Confidence score (0-1)
  final String transcript;  // Raw transcribed text
  final int matchScore;     // Fuzzy match score (0-100)

  DetectedPokerAction({
    required this.action,
    this.amount,
    required this.confidence,
    required this.transcript,
    this.matchScore = 100,
  });

  @override
  String toString() => 'DetectedPokerAction($action, amount: $amount, confidence: ${confidence.toStringAsFixed(2)}, matchScore: $matchScore)';
}

/// Debouncer to prevent duplicate rapid actions
class _ActionDebouncer {
  DateTime? _lastActionTime;
  String? _lastAction;

  static const int sameActionCooldownMs = 2000;  // 2 seconds for same action
  static const int anyActionCooldownMs = 500;    // 0.5 seconds for any action

  bool canExecute(String action) {
    final now = DateTime.now();
    if (_lastActionTime == null) {
      _lastActionTime = now;
      _lastAction = action;
      return true;
    }

    final elapsed = now.difference(_lastActionTime!).inMilliseconds;

    // Same action needs longer cooldown
    if (action == _lastAction && elapsed < sameActionCooldownMs) {
      debugPrint('Debouncer: Blocking duplicate $action (${elapsed}ms since last)');
      return false;
    }

    // Any action needs minimum cooldown
    if (elapsed < anyActionCooldownMs) {
      debugPrint('Debouncer: Blocking rapid action (${elapsed}ms since last)');
      return false;
    }

    _lastActionTime = now;
    _lastAction = action;
    return true;
  }

  void reset() {
    _lastActionTime = null;
    _lastAction = null;
  }
}

/// Service for continuous speech recognition of poker actions
/// Uses on-device speech recognition for low latency with fuzzy matching
class ContinuousSpeechService {
  static final ContinuousSpeechService _instance = ContinuousSpeechService._internal();
  factory ContinuousSpeechService() => _instance;
  ContinuousSpeechService._internal();

  static ContinuousSpeechService get instance => _instance;

  final SpeechToText _speech = SpeechToText();
  final _ActionDebouncer _debouncer = _ActionDebouncer();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isRestarting = false;
  int _consecutiveErrors = 0;

  // Configurable locale for speech recognition
  // Default: 'en_US', can be changed to 'pl_PL' for Polish
  String _localeId = 'en_US';

  /// Set the speech recognition locale
  /// Common values: 'en_US', 'en_GB', 'pl_PL' (Polish)
  void setLocale(String localeId) {
    _localeId = localeId;
    debugPrint('ContinuousSpeechService: Locale set to $_localeId');
  }

  /// Get available locales on this device
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();
    return _speech.locales();
  }

  // Stream controllers
  final _actionController = StreamController<DetectedPokerAction>.broadcast();
  Stream<DetectedPokerAction> get actionStream => _actionController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  final _partialController = StreamController<String>.broadcast();
  Stream<String> get partialStream => _partialController.stream;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  // ============================================================
  // COMPREHENSIVE ACTION KEYWORDS WITH COMMON MISRECOGNITIONS
  // ============================================================
  static const Map<String, List<String>> _actionKeywords = {
    'fold': [
      // Correct forms
      'fold', 'folds', 'folding', 'folded', 'muck', 'mucks', 'mucking',
      // Common misrecognitions (phonetically similar)
      'cold', 'colds', 'fault', 'faults', 'hold', 'holds', 'holding',
      'foul', 'fouls', 'old', 'gold', 'bold', 'told', 'mold', 'sold',
      'photo', 'folder', 'follow',
    ],
    'check': [
      // Correct forms
      'check', 'checks', 'checking', 'checked',
      // Pass = check in poker
      'pass', 'passes', 'passing', 'passed',
      // Common misrecognitions
      'tech', 'deck', 'decks', 'czech', 'shake', 'shakes',
      'chick', 'chuck', 'neck', 'wreck', 'trek', 'jack',
      'chicken', 'checker', 'checkout',
      'pause', 'pauses', 'chess', 'chest', 'pats', 'path',
    ],
    'call': [
      // Correct forms
      'call', 'calls', 'calling', 'called',
      // Poker slang for calling
      'flat', 'flats', 'flatting', 'flatted',
      'pay', 'pays', 'paying', 'paid',
      // Common misrecognitions
      'coal', 'cool', 'carl', 'cull', 'col',
      'tall', 'fall', 'ball', 'wall', 'hall', 'mall', 'all',
      'caller', 'crawl', 'paul', 'car', 'cow',
    ],
    'bet': [
      // Correct forms
      'bet', 'bets', 'betting', 'betted',
      // Poker terms for betting
      'open', 'opens', 'opening', 'opened',
      'lead', 'leads', 'leading', 'led',
      'put', 'puts', 'putting',
      // Common misrecognitions
      'bit', 'bits', 'bat', 'bats', 'but', 'butt',
      'best', 'bent', 'bait', 'bed', 'beds',
      'set', 'sets', 'pet', 'pets', 'get', 'gets', 'let', 'lets',
      'wet', 'wets', 'yet', 'met', 'net', 'vet',
      'better', 'bitter',
    ],
    'raise': [
      // Correct forms
      'raise', 'raises', 'raising', 'raised',
      'bump', 'bumps', 'bumping',
      'make it', 'makes it',
      // Common misrecognitions
      'race', 'races', 'racing', 'rays', 'raze', 'razes',
      'rage', 'rages', 'rise', 'rises', 'rising', 'rose',
      'praise', 'praises', 'phrase', 'phrases',
      'erase', 'erases', 'graze', 'grazes', 'craze',
      'braise', 'braised', 'raisin', 'razor',
    ],
    'all-in': [
      // Correct forms
      'all in', 'all-in', 'allin', 'all end', 'allen',
      'shove', 'shoves', 'shoving', 'shoved',
      'jam', 'jams', 'jamming', 'jammed',
      'push', 'pushes', 'pushing', 'pushed',
      // Common misrecognitions
      'all and', 'olden', 'online', 'calling', 'falling',
      'olin', 'alan', 'allan', 'allen', 'alone',
      'show', 'shows', 'chop', 'chops',
    ],
  };

  // ============================================================
  // CONFIDENCE THRESHOLDS PER ACTION (higher stakes = higher threshold)
  // ============================================================
  static const Map<String, double> _confidenceThresholds = {
    'fold': 0.50,      // Lower - common action, easy to undo mentally
    'check': 0.50,     // Lower - low stakes action
    'call': 0.55,      // Medium - commits chips
    'bet': 0.60,       // Higher - aggressive action with amount
    'raise': 0.60,     // Higher - aggressive action with amount
    'all-in': 0.70,    // Highest - irreversible commitment
  };

  // Minimum fuzzy match score to consider (0-100)
  static const int _minFuzzyMatchScore = 65;

  // ============================================================
  // ENHANCED WORD TO NUMBER MAPPING (English + Polish)
  // ============================================================
  static const Map<String, int> _wordToNumber = {
    // === ENGLISH NUMBERS ===
    // Basic numbers
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    // Tens
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    // Multipliers
    'hundred': 100, 'thousand': 1000,
    // Poker slang
    'k': 1000, 'grand': 1000,
    // Common misrecognitions for numbers
    'to': 2, 'too': 2, 'for': 4, 'fore': 4,
    'won': 1, 'ate': 8, 'tree': 3,

    // === POLISH NUMBERS ===
    // Basic numbers (1-10)
    'jeden': 1, 'dwa': 2, 'trzy': 3, 'cztery': 4, 'pięć': 5,
    'sześć': 6, 'siedem': 7, 'osiem': 8, 'dziewięć': 9, 'dziesięć': 10,
    // Teens (11-19)
    'jedenaście': 11, 'dwanaście': 12, 'trzynaście': 13, 'czternaście': 14,
    'piętnaście': 15, 'szesnaście': 16, 'siedemnaście': 17, 'osiemnaście': 18,
    'dziewiętnaście': 19,
    // Tens (20-90)
    'dwadzieścia': 20, 'trzydzieści': 30, 'czterdzieści': 40, 'pięćdziesiąt': 50,
    'sześćdziesiąt': 60, 'siedemdziesiąt': 70, 'osiemdziesiąt': 80, 'dziewięćdziesiąt': 90,
    // Hundreds
    'sto': 100, 'dwieście': 200, 'trzysta': 300, 'czterysta': 400,
    'pięćset': 500, 'sześćset': 600, 'siedemset': 700, 'osiemset': 800,
    'dziewięćset': 900,
    // Thousands
    'tysiąc': 1000, 'tysiac': 1000,

    // === POLISH PHONETIC MISRECOGNITIONS ===
    // (How English speech recognition might transcribe Polish words)
    // "sto" (100) misrecognitions (note: 'sto' already defined above)
    'stow': 100, 'stowe': 100, 'stough': 100,
    // "dwa" (2) misrecognitions
    'dva': 2, 'dwah': 2,
    // "trzy" (3) misrecognitions (note: 'tree' already defined above)
    'tshi': 3, 'tchi': 3, 'chi': 3,
    // "cztery" (4) misrecognitions
    'chteri': 4, 'shteri': 4,
    // "pięć" (5) misrecognitions
    'piench': 5, 'pench': 5, 'pyench': 5,
    // "sześć" (6) misrecognitions
    'sheshch': 6, 'shesh': 6,
    // "siedem" (7) misrecognitions (note: 'siedem' already defined above)
    'shedem': 7,
    // "osiem" (8) misrecognitions
    'oshem': 8, 'osyem': 8,
    // "dziewięć" (9) misrecognitions
    'djeviench': 9, 'jevyench': 9,
    // "dziesięć" (10) misrecognitions
    'djeshench': 10, 'jeshench': 10,
    // "dwadzieścia" (20) misrecognitions
    'dvajeshcha': 20, 'dwajeshcha': 20,
    // "pięćdziesiąt" (50) misrecognitions
    'pyenchjesont': 50, 'pienchjesont': 50,
    // "tysiąc" (1000) misrecognitions
    'tishonts': 1000, 'tysionts': 1000,
  };

  // ============================================================
  // INITIALIZATION
  // ============================================================
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('ContinuousSpeechService: Initializing...');

      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,  // Reduce log spam
      );

      if (_isInitialized) {
        debugPrint('ContinuousSpeechService: Initialized successfully');
      } else {
        debugPrint('ContinuousSpeechService: Failed to initialize');
      }

      return _isInitialized;
    } catch (e, stack) {
      debugPrint('ContinuousSpeechService: Error initializing: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  // ============================================================
  // STATUS AND ERROR HANDLERS WITH EXPONENTIAL BACKOFF
  // ============================================================
  void _onStatus(String status) {
    debugPrint('ContinuousSpeechService: Status: $status');
    _statusController.add(status);

    // Auto-restart with protection against rapid restarts
    if (status == 'done' && _isListening && !_isRestarting) {
      _isRestarting = true;
      _consecutiveErrors = 0;  // Reset error count on successful completion

      // Longer delay to prevent error_busy
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_isListening) {
          _startListeningInternal().whenComplete(() {
            _isRestarting = false;
          });
        } else {
          _isRestarting = false;
        }
      });
    }
  }

  void _onError(dynamic error) {
    debugPrint('ContinuousSpeechService: Error: $error');
    _consecutiveErrors++;

    // Exponential backoff for errors (500ms, 1s, 2s, 4s, max 5s)
    final delay = min(500 * pow(2, _consecutiveErrors - 1).toInt(), 5000);

    debugPrint('ContinuousSpeechService: Retry in ${delay}ms (attempt $_consecutiveErrors)');

    if (_isListening && !_isRestarting && _consecutiveErrors < 10) {
      _isRestarting = true;
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isListening) {
          _startListeningInternal().whenComplete(() {
            _isRestarting = false;
          });
        } else {
          _isRestarting = false;
        }
      });
    } else if (_consecutiveErrors >= 10) {
      debugPrint('ContinuousSpeechService: Too many errors, stopping');
      _isListening = false;
      _statusController.add('error_max_retries');
    }
  }

  // ============================================================
  // START/STOP LISTENING
  // ============================================================
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    _isListening = true;
    _consecutiveErrors = 0;
    _debouncer.reset();
    return _startListeningInternal();
  }

  Future<bool> _startListeningInternal() async {
    if (!_isListening) return false;

    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: _localeId,  // Use configured locale
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
      debugPrint('ContinuousSpeechService: Listening with locale $_localeId');
      return true;
    } catch (e) {
      debugPrint('ContinuousSpeechService: Error starting listen: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    _isRestarting = false;
    _consecutiveErrors = 0;
    await _speech.stop();
    _partialController.add('');
    debugPrint('ContinuousSpeechService: Stopped listening');
  }

  // ============================================================
  // SPEECH RESULT PROCESSING
  // ============================================================
  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase().trim();

    if (text.isEmpty) return;

    // Send partial results for UI feedback
    if (!result.finalResult) {
      _partialController.add(text);
      return;
    }

    debugPrint('ContinuousSpeechService: Final result: "$text" (confidence: ${result.confidence.toStringAsFixed(2)})');
    _partialController.add('');

    // Parse the text for poker actions
    final action = _parsePokerAction(text, result.confidence);
    if (action != null) {
      // Check debouncer
      if (_debouncer.canExecute(action.action)) {
        debugPrint('ContinuousSpeechService: Detected action: $action');
        _actionController.add(action);
      } else {
        debugPrint('ContinuousSpeechService: Action debounced: ${action.action}');
      }
    } else {
      debugPrint('ContinuousSpeechService: No poker action found in: "$text"');
    }
  }

  // ============================================================
  // ACTION PARSING WITH FUZZY MATCHING
  // ============================================================
  DetectedPokerAction? _parsePokerAction(String text, double confidence) {
    final lowerText = text.toLowerCase().trim();

    // Remove common filler words
    final cleanedText = _removeFiller(lowerText);

    String? bestAction;
    int bestScore = 0;
    String? matchedKeyword;

    // Step 1: Try exact/contains match first (fast path)
    for (final entry in _actionKeywords.entries) {
      final actionType = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (cleanedText.contains(keyword) || cleanedText == keyword) {
          // Exact match gets score of 100
          if (100 > bestScore) {
            bestScore = 100;
            bestAction = actionType;
            matchedKeyword = keyword;
          }
        }
      }
    }

    // Step 2: If no exact match, try fuzzy matching
    if (bestAction == null || bestScore < 100) {
      // Split text into words and check each
      final words = cleanedText.split(RegExp(r'\s+'));

      for (final word in words) {
        if (word.length < 2) continue;  // Skip very short words

        for (final entry in _actionKeywords.entries) {
          final actionType = entry.key;
          final keywords = entry.value;

          for (final keyword in keywords) {
            // Use Levenshtein ratio for fuzzy matching
            final score = ratio(word, keyword);

            if (score > bestScore && score >= _minFuzzyMatchScore) {
              bestScore = score;
              bestAction = actionType;
              matchedKeyword = keyword;
            }
          }
        }
      }
    }

    if (bestAction == null) {
      return null;
    }

    // Calculate effective confidence (combine ASR confidence with match score)
    final effectiveConfidence = confidence * (bestScore / 100);

    // Check if meets threshold for this action
    final threshold = _confidenceThresholds[bestAction] ?? 0.55;
    if (effectiveConfidence < threshold) {
      debugPrint('ContinuousSpeechService: Below threshold - $bestAction (${effectiveConfidence.toStringAsFixed(2)} < $threshold)');
      return null;
    }

    // Extract amount for bet/raise
    double? amount;
    if (bestAction == 'bet' || bestAction == 'raise') {
      amount = _extractAmount(cleanedText);
    }

    debugPrint('ContinuousSpeechService: Matched "$matchedKeyword" -> $bestAction (score: $bestScore, confidence: ${effectiveConfidence.toStringAsFixed(2)})');

    return DetectedPokerAction(
      action: bestAction,
      amount: amount,
      confidence: effectiveConfidence,
      transcript: text,
      matchScore: bestScore,
    );
  }

  /// Remove common filler words and phrases
  String _removeFiller(String text) {
    // Common filler words/phrases to remove
    const fillers = [
      'um', 'uh', 'like', 'you know', 'i mean', 'so', 'well',
      'he', 'she', 'they', 'player', 'seat', 'the', 'a', 'an',
      'is', 'are', 'was', 'were', 'has', 'have', 'had',
      'i', 'we', 'you', 'it', 'that', 'this', 'there',
      'gonna', 'going to', 'want to', 'wants to',
    ];

    var result = text;
    for (final filler in fillers) {
      result = result.replaceAll(RegExp('\\b$filler\\b'), ' ');
    }

    // Clean up multiple spaces
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ============================================================
  // AMOUNT EXTRACTION
  // ============================================================
  double? _extractAmount(String text) {
    // Try to find numeric values first (including with commas)
    final numericPattern = RegExp(r'\b(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\b');
    final numericMatch = numericPattern.firstMatch(text);
    if (numericMatch != null) {
      final numStr = numericMatch.group(1)!.replaceAll(',', '');
      return double.tryParse(numStr);
    }

    // Try word-based numbers
    double total = 0;
    double current = 0;
    bool foundNumber = false;

    final words = text.split(RegExp(r'\s+'));
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w-]'), '').toLowerCase();

      if (_wordToNumber.containsKey(cleanWord)) {
        foundNumber = true;
        final value = _wordToNumber[cleanWord]!;

        if (value == 100) {
          current = (current == 0 ? 1 : current) * 100;
        } else if (value == 1000) {
          current = (current == 0 ? 1 : current) * 1000;
          total += current;
          current = 0;
        } else {
          current += value;
        }
      }
    }

    total += current;
    return foundNumber && total > 0 ? total : null;
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================
  Future<bool> isAvailable() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }

  void dispose() {
    _isListening = false;
    _speech.stop();
    _actionController.close();
    _statusController.close();
    _partialController.close();
  }
}
