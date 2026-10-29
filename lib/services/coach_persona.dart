import 'package:shared_preferences/shared_preferences.dart';

import '../utils/coach_text.dart';

import '../models/drill_models.dart';

/// Daily Challenge coach personas: character lives in the WRITING; the
/// voice casting is server-side in the `coachSpeech` Cloud Function. Each
/// persona rewrites the verdict lead in its own voice and keeps the grader's
/// factual reason untouched (the coaching content never changes, only the
/// delivery). All personas are ORIGINAL characters — never real players
/// (personality rights).
///
/// Lead templates use `{action}` (lowercase recommended action); rotation is
/// deterministic by decision index so replays of the shared daily puzzle
/// sound the same for everyone. English-only while the feature is flagged.
class CoachPersona {
  final String id;
  final String name;
  final String tagline;
  final String greeting; // spoken when picked / shown on the intro

  final List<String> correctLeads;
  final List<String> okLeads;
  final List<String> mistakeLeads;

  const CoachPersona({
    required this.id,
    required this.name,
    required this.tagline,
    required this.greeting,
    required this.correctLeads,
    required this.okLeads,
    required this.mistakeLeads,
  });

  String _lead(DrillGrade grade, String action, int n) {
    final pool = switch (grade) {
      DrillGrade.correct => correctLeads,
      DrillGrade.ok => okLeads,
      DrillGrade.mistake => mistakeLeads,
    };
    return normalizeCoachText(
        pool[n % pool.length].replaceAll('{action}', action));
  }

  /// The full coach line for one graded decision: persona lead + the
  /// reason + the GTO-vs-exploit note when the lines diverge. [n] is the
  /// decision index (0-based) — drives deterministic lead rotation.
  ///
  /// [aiLine] (optional) is the AI-generated, level-adapted, full line for
  /// this coach — opener and reasoning in one, already in this coach's
  /// voice at the player's level. When present it IS the whole line (no
  /// template lead is prepended, no GTO note appended). Falls back to the
  /// template lead + grader reason when null/empty.
  String compose(DrillGradeResult grade, int n, {String? aiLine}) {
    if (aiLine != null && aiLine.trim().isNotEmpty) return normalizeCoachText(aiLine);

    final reason = grade.headlineReason.isNotEmpty
        ? grade.headlineReason
        : grade.explanation;
    // Lead tier: an OK verdict where the hero PICKED the solver's top action
    // (it's just a thin mix) must NOT use the "but {action} edges it" leads —
    // that implies a better line when there isn't one. Lead with the "correct"
    // pool instead; the reason already explains it's a close mix.
    final leadGrade =
        (grade.grade == DrillGrade.ok && grade.heroAction == grade.recommendedAction)
            ? DrillGrade.correct
            : grade.grade;
    // Use the street-aware recommended WORD ('bet' vs 'raise'), not the raw
    // wire action (which always reads 'raise') — so a flop bet never shows as
    // "raise edges it".
    return joinSentences([
      _lead(leadGrade, grade.recommendedWord, n),
      reason,
      if (!grade.linesAgree)
        '(Pure GTO would ${grade.gtoAction} here — against this '
            'table, ${grade.exploitAction} is the better line.)',
    ]);
  }
}

class CoachPersonas {
  CoachPersonas._();

  static const String _prefKey = 'coach_persona_id';

  static const grinder = CoachPersona(
    id: 'grinder',
    name: 'Duke',
    tagline: 'Old-school Vegas grinder',
    greeting: "Name's Duke. Forty years at the felt. "
        "Show me you can fold, kid.",
    correctLeads: [
      'Snap {action}, kid. Just like downtown.',
      "That's a {action} all day long.",
      'Textbook {action}. The old crew would approve.',
      "{action} — now you're playing real poker.",
    ],
    okLeads: [
      "Eh, close enough — but {action} squeezes out a little more.",
      "I've seen worse. Still, {action} is the money line.",
      'Half right, kid. {action} was the sharper play.',
    ],
    mistakeLeads: [
      "Nah, kid. {action} was the move.",
      "You're bleeding chips — that spot screams {action}.",
      "Back in my day that cost you the rent. {action} there.",
    ],
  );

  static const professor = CoachPersona(
    id: 'professor',
    name: 'Prof. Vega',
    tagline: 'Dry GTO theorist',
    greeting: 'Professor Vega. We will proceed by equilibrium. '
        'Deviations will be noted.',
    correctLeads: [
      '{action} — precisely the equilibrium-adjusted line.',
      'Correct. {action} maximizes expected value here.',
      'As the solver intends: {action}.',
      'Optimal. {action} is indicated.',
    ],
    okLeads: [
      'Marginally suboptimal — {action} edges it on EV.',
      'Within tolerance, though {action} is the finer choice.',
      'A rounding error from correct: {action} is preferred.',
    ],
    mistakeLeads: [
      'Deviation detected: {action} was correct.',
      'The data disagrees — {action} is the line.',
      'An EV leak. {action} was indicated.',
    ],
  );

  static const nova = CoachPersona(
    id: 'nova',
    name: 'Nova',
    tagline: 'High-energy hype coach',
    greeting: "Nova here! Five spots, full focus \u2014 bring your "
        "A-game and let's make it a perfect day!",
    correctLeads: [
      'BOOM! {action} was the play!',
      "That's it \u2014 {action}, textbook!",
      'YES! {action} like a champ!',
      'On fire \u2014 {action} is exactly right!',
    ],
    okLeads: [
      'So close! {action} squeezes out a little more!',
      'Almost \u2014 {action} is the sharper line!',
      'Good instinct, but {action} edges it!',
    ],
    mistakeLeads: [
      'Ouch \u2014 {action} was the move!',
      'Shake it off \u2014 {action} next time!',
      'We learn, we adjust: {action} there!',
    ],
  );

  static const List<CoachPersona> all = [grinder, professor, nova];

  static CoachPersona byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => grinder);

  static Future<CoachPersona> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return byId(prefs.getString(_prefKey));
    } catch (_) {
      return grinder;
    }
  }

  static Future<void> save(CoachPersona persona) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, persona.id);
    } catch (_) {}
  }
}
