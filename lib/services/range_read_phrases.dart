import 'daily_coach_lines_service.dart';
import 'range_read_logic.dart';

/// Persona-voiced flavour lines for Range Read (English-only, like the rest
/// of the persona text while the Daily Challenge is flagged). Pure.
class RangeReadPhrases {
  RangeReadPhrases._();

  static const Map<String, List<String>> _intro = {
    'grinder': [
      'Quick one, kid. Read the range.',
      "Let's see if you know what's in your range.",
    ],
    'professor': [
      'A brief range exercise.',
      'Consider the range, if you will.',
    ],
    'nova': [
      'Range read time! You got this!',
      'Bonus round! Read that range!',
    ],
  };

  static const Map<String, List<String>> _right = {
    'grinder': ["That's it, kid. You can read a range.", 'Sharp. Very sharp.'],
    'professor': ['Correct. The frequencies agree.', 'Precisely so.'],
    'nova': ['YES! Range reader!', 'BOOM! Nailed it!'],
  };

  static const Map<String, List<String>> _wrong = {
    'grinder': ["Nah, kid. Look at the numbers.", "Close, but no cigar."],
    'professor': ['Incorrect. Note the frequencies.', 'The data says otherwise.'],
    'nova': ['Ooh, not this time! Check the numbers!', 'Shake it off, next one!'],
  };

  static String _pick(Map<String, List<String>> pool, String personaId,
      String seed) {
    final list = pool[personaId] ?? pool['grinder']!;
    return list[DailyCoachLinesService.stableHash(seed) % list.length];
  }

  static String intro(String personaId, String seed) =>
      _pick(_intro, personaId, '$seed|intro');

  static String reaction(String personaId, bool right, String seed) =>
      _pick(right ? _right : _wrong, personaId, '$seed|react');

  /// English question text, spoken by the coach (the card shows a localized
  /// version).
  static String spokenQuestion(RangeReadQuestion q) =>
      q.type == RangeReadType.also
          ? 'Which of these hands would also ${q.actionWord} here?'
          : 'Which of these hands would not ${q.actionWord} here?';
}
