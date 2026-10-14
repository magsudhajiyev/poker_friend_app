import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Neural coach voice for the Daily Challenge — ElevenLabs via the
/// `coachSpeech` Cloud Function (key server-side in Secret Manager), cached
/// twice: Storage per unique line (the daily puzzle is shared, one
/// generation serves everyone) and on-device (replays work offline).
///
/// There is deliberately NO device-TTS fallback: a robotic voice undercuts
/// the coach characters, so on any failure (offline, signed out, backend
/// down) the coach simply stays quiet — the typed bubble still carries the
/// content. Fire-and-forget contract: every call swallows errors.
/// Where the coach's voice currently is — UIs show a "thinking" indicator
/// during [loading] (first-time lines take 1-3s to synthesize + download).
enum CoachSpeechState { idle, loading, speaking }

class CoachVoiceService {
  CoachVoiceService._();

  static const String _prefKey = 'coach_voice_enabled';
  static const String _speechEndpoint =
      'https://us-central1-poker-tracker-52df8.cloudfunctions.net/coachSpeech';

  static AudioPlayer? _player;
  static bool _playerConfigured = false;
  static bool _enabled = true;
  static bool _prefLoaded = false;
  static int _speakSeq = 0;

  /// Observable speech state for "coach is thinking…" indicators.
  static final ValueNotifier<CoachSpeechState> speechState =
      ValueNotifier<CoachSpeechState>(CoachSpeechState.idle);

  /// Duration of the clip that plays now. Null until the player reports
  /// it. UIs use it to time events to the speech (card highlight).
  static final ValueNotifier<Duration?> clipDuration =
      ValueNotifier<Duration?>(null);

  /// The exact text sent to the voice (after notation expansion and
  /// trimming). Mention timing must search THIS text, not the typed one.
  static String lastSpokenText = '';

  static void _setState(int seq, CoachSpeechState value) {
    // Only the most recent speak() owns the state — a superseded fetch
    // must not stomp the indicator of the line that replaced it.
    if (seq == _speakSeq) speechState.value = value;
  }

  /// Speak [text] in [coachId]'s voice, replacing anything currently
  /// playing. No-op when muted; silent on any failure. A later speak()
  /// always wins — a slow fetch never talks over a newer line.
  static Future<void> speak(String text, {required String coachId}) async {
    try {
      await loadEnabled();
      if (!_enabled || text.trim().isEmpty) return;
      final seq = ++_speakSeq;
      await stop0();
      _setState(seq, CoachSpeechState.loading);
      clipDuration.value = null;

      final spoken = _trimForSpeech(speakable(text));
      final file = await _fetchNeuralClip(coachId, spoken);
      if (file == null || seq != _speakSeq || !_enabled) {
        _setState(seq, CoachSpeechState.idle);
        return;
      }
      _player ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          speechState.value = CoachSpeechState.idle;
        })
        ..onDurationChanged.listen((d) {
          clipDuration.value = d;
        });
      await _configurePlayerContext();
      lastSpokenText = spoken;
      await _player!.play(DeviceFileSource(file.path));
      _setState(seq, CoachSpeechState.speaking);
    } catch (_) {
      speechState.value = CoachSpeechState.idle;
    }
  }

  /// Warm the caches for a line WITHOUT playing it (e.g. the three picker
  /// greetings while the intro screen is open) — the eventual speak() is
  /// then instant. Fire-and-forget; never throws.
  static Future<void> prefetch(String text, {required String coachId}) async {
    try {
      await loadEnabled();
      if (!_enabled || text.trim().isEmpty) return;
      await _fetchNeuralClip(coachId, _trimForSpeech(speakable(text)));
    } catch (_) {}
  }

  /// The backend caps line length (cost control). Long coach lines are
  /// trimmed at a sentence boundary instead of failing silently — a
  /// shortened spoken line beats a mute coach (bug 2026-10-14: verbose
  /// mistake explanations exceeded the cap after notation expansion).
  static String _trimForSpeech(String text) {
    const max = 550;
    if (text.length <= max) return text;
    final cut = text.substring(0, max);
    final end = cut.lastIndexOf(RegExp(r'[.!?]'));
    return end > 200 ? cut.substring(0, end + 1) : cut;
  }

  /// One-time audio session config: playback category on iOS (speaks over
  /// the silent switch — the user explicitly opened a voiced challenge);
  /// media stream on Android (system-sounds stream is muted on many ROMs).
  static Future<void> _configurePlayerContext() async {
    if (_playerConfigured) return;
    await AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {
          AVAudioSessionOptions.duckOthers,
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: const AudioContextAndroid(
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    ));
    _playerConfigured = true;
  }

  /// Download (or reuse the on-device copy of) one neural clip. Returns
  /// null on ANY problem — the coach stays quiet rather than degrading.
  /// Bump when a coach is recast so stale on-device clips stop playing.
  static const int _voiceCacheVersion = 2;

  static Future<File?> _fetchNeuralClip(String coach, String text) async {
    try {
      final hash = sha256
          .convert(utf8.encode('v$_voiceCacheVersion|$coach|$text'))
          .toString();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/coach_voice/$coach-$hash.mp3');
      if (await file.exists()) return file;

      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return null;
      final response = await http
          .post(
            Uri.parse(_speechEndpoint),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'text': text, 'coach': coach}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('coach voice: coachSpeech ${response.statusCode} '
              '(coach=$coach, len=${text.length})');
        }
        return null;
      }
      final url = (jsonDecode(response.body) as Map)['url'] as String?;
      if (url == null) return null;

      // Firebase Storage download URLs throw intermittent 500s — retry
      // with a short backoff instead of going silent (observed in prod).
      http.Response? audio;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final r = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 8));
          if (r.statusCode == 200) {
            audio = r;
            break;
          }
          if (kDebugMode) {
            debugPrint('coach voice: clip download ${r.statusCode} '
                '(attempt ${attempt + 1}/3)');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('coach voice: clip download error $e '
                '(attempt ${attempt + 1}/3)');
          }
        }
        await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
      if (audio == null) return null;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(audio.bodyBytes);
      return file;
    } catch (e) {
      if (kDebugMode) debugPrint('coach voice: fetch failed: $e');
      return null;
    }
  }

  /// Internal stop that does NOT cancel in-flight fetches.
  static Future<void> stop0() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  static Future<void> stop() async {
    _speakSeq++; // cancel any in-flight fetch
    speechState.value = CoachSpeechState.idle;
    await stop0();
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    _prefLoaded = true;
    if (!value) await stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  static Future<bool> loadEnabled() async {
    if (!_prefLoaded) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _enabled = prefs.getBool(_prefKey) ?? true;
      } catch (_) {}
      _prefLoaded = true;
    }
    return _enabled;
  }

  // ── Speech transform (pure, unit-tested) ─────────────────────────────

  static const Map<String, String> _rankNames = {
    'A': 'ace',
    'K': 'king',
    'Q': 'queen',
    'J': 'jack',
    'T': 'ten',
    '9': 'nine',
    '8': 'eight',
    '7': 'seven',
    '6': 'six',
    '5': 'five',
    '4': 'four',
    '3': 'three',
    '2': 'two',
  };

  static const List<String> _smallNumbers = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
    'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
    'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];
  static const List<String> _tensNumbers = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety',
  ];

  /// Integer → English words (0-999). Larger values stay digits.
  static String _numberWords(int n) {
    if (n < 20) return _smallNumbers[n];
    if (n < 100) {
      final tens = _tensNumbers[n ~/ 10];
      final rest = n % 10;
      return rest == 0 ? tens : '$tens-${_smallNumbers[rest]}';
    }
    if (n < 1000) {
      final hundreds = '${_smallNumbers[n ~/ 100]} hundred';
      final rest = n % 100;
      return rest == 0 ? hundreds : '$hundreds ${_numberWords(rest)}';
    }
    return '$n';
  }

  /// Rewrites poker notation into words the voice can say naturally:
  /// 'A5s' → 'ace five suited', 'AKo' → 'ace king offsuit',
  /// '72 off' / '72 offsuit' → 'seven two offsuit' (not "seventy-two"),
  /// 'QQ' → 'pocket queens', '2.5BB' → '2.5 big blinds', '24%' →
  /// 'twenty-four percent'. Everything else passes through untouched.
  static String speakable(String text) {
    // Pre-pass: a rank pair written with a SPACED or WORDED suffix —
    // '72 off', '72 offsuit', 'T9 suited', 'A5 off', even '72o suited'
    // (redundant) — is folded into the glued class ('72o' / 'T9s') so the
    // main pass below says "seven two offsuit", not "seventy-two off".
    // Without this a bare digit pair like '72' reads as "seventy-two".
    var out = text.replaceAllMapped(
      RegExp(
          r'\b([AKQJT2-9])([AKQJT2-9])[so]?\s+(suited|offsuit|off|suit)\b',
          caseSensitive: false),
      (m) {
        final glued = m[3]!.toLowerCase().startsWith('s') ? 's' : 'o';
        return '${m[1]}${m[2]}$glued';
      },
    );
    // Hand classes. Guards: a number before '%', a decimal, or a BB size
    // is NOT a hand ('24%' once became 'two four percent'). A bare
    // digit pair with two DIFFERENT digits is a plain number, not a hand
    // — real digit hands carry an s/o suffix ('72o') or equal digits
    // ('22' = pocket twos).
    out = out.replaceAllMapped(
      RegExp(r'\b([AKQJT2-9])([AKQJT2-9])(s|o)?\b(?!%|\.\d|\s?BB\b)'),
      (m) {
        final bothDigits = RegExp(r'\d').hasMatch(m[1]!) &&
            RegExp(r'\d').hasMatch(m[2]!);
        if (bothDigits && m[3] == null && m[1] != m[2]) {
          return m[0]!; // plain number such as '24' — leave it alone
        }
        final r1 = _rankNames[m[1]]!;
        final r2 = _rankNames[m[2]]!;
        if (m[1] == m[2]) return 'pocket ${r2}s';
        final suffix = switch (m[3]) {
          's' => ' suited',
          'o' => ' offsuit',
          _ => '',
        };
        return '$r1 $r2$suffix';
      },
    );
    // Bet sizes: '2.5BB' / '15BB' → 'big blinds'; the bare position 'BB'
    // is left alone (no digit before it).
    out = out.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s?BB\b'),
      (m) => '${m[1]} big blinds',
    );
    // Rank-x shorthand: 'A-x' / 'Ax' → 'ace-x', 'K-x' → 'king-x'. A
    // proper coach says "ace-x suited", not "A-x suited".
    out = out.replaceAllMapped(
      RegExp(r'\b([AKQJT])-?x\b'),
      (m) => '${_rankNames[m[1]]}-x',
    );
    // Percentages → full words, so the voice never spells digits:
    // '24%' → 'twenty-four percent', '12.5%' → 'twelve point five percent'.
    out = out.replaceAllMapped(
      RegExp(r'(\d+)(?:\.(\d+))?\s?%'),
      (m) {
        final whole = _numberWords(int.parse(m[1]!));
        final dec = m[2];
        if (dec == null) return '$whole percent';
        final digits =
            dec.split('').map((d) => _smallNumbers[int.parse(d)]).join(' ');
        return '$whole point $digits percent';
      },
    );
    return out;
  }
}
