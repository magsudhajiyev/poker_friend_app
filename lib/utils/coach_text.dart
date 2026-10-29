/// Pure punctuation / capitalisation helpers for coach lines.
///
/// Coach text is assembled from several sources (persona lead, authored
/// explanation, AI variant, hand note). Each source may lack a final stop or
/// start lowercase, so every join goes through these helpers.

const _closers = '"\'’”)';
final RegExp _terminal = RegExp('[.!?…][$_closers]*\$');
final RegExp _ws = RegExp(r'\s+');
final RegExp _sentenceBreak =
    RegExp('([.!?][$_closers]*)(\\s+)(\\p{Ll})', unicode: true);
final RegExp _doubleDot = RegExp(r'(?<!\.)\.\.(?!\.)');

/// Words that end in '.' but do not end a sentence.
const _abbreviations = {
  'vs',
  'e.g',
  'i.e',
  'etc',
  'approx',
  'incl',
  'eg',
  'ie',
  'mr',
  'dr',
};

/// Normalises one coach text: whitespace collapsed, sentence starts
/// capitalised, spacing around punctuation fixed, final stop ensured.
/// Idempotent. Returns '' for null/blank input.
String normalizeCoachText(String s) {
  // A line break is a sentence boundary: authored text often has a heading
  // phrase ("Flatting a suited ace in position") on its own line with no stop.
  final lines = s
      .split(RegExp(r'\s*[\r\n]+\s*'))
      .map(_normalizeLine)
      .where((l) => l.isNotEmpty);
  return lines.join(' ');
}

String _normalizeLine(String s) {
  var t = s.replaceAll(_ws, ' ').trim();
  if (t.isEmpty) return '';
  t = t
      .replaceAllMapped(RegExp(r' +([,.;:!?])'), (m) => m[1]!)
      .replaceAll(_doubleDot, '.');
  t = t.replaceAllMapped(_sentenceBreak, (m) {
    final before = t.substring(0, m.start + 1); // up to and incl. the stop
    if (m[1]!.startsWith('.') && _endsWithAbbreviation(before)) {
      return m[0]!;
    }
    return '${m[1]}${m[2]}${m[3]!.toUpperCase()}';
  });
  t = _capitaliseStart(t);
  t = t.replaceAll(RegExp(r'[,;:—\-]+$'), '').trimRight();
  if (t.isEmpty) return '';
  return _terminal.hasMatch(t) ? t : '$t.';
}

bool _endsWithAbbreviation(String upToStop) {
  final m = RegExp(r'([A-Za-z.]+)\.$').firstMatch(upToStop);
  if (m == null) return false;
  return _abbreviations.contains(m[1]!.toLowerCase());
}

String _capitaliseStart(String t) {
  var i = 0;
  while (i < t.length && '("\'“‘¿¡'.contains(t[i])) {
    i++;
  }
  if (i >= t.length) return t;
  final c = t[i];
  if (c.toLowerCase() == c.toUpperCase()) return t; // digit, card glyph, ...
  return t.replaceRange(i, i + 1, c.toUpperCase());
}

/// Joins sentence parts with ONE space, normalising each part first
/// (null/blank parts are skipped).
String joinSentences(Iterable<String?> parts) {
  final out = <String>[];
  for (final p in parts) {
    if (p == null) continue;
    final n = normalizeCoachText(p);
    if (n.isNotEmpty) out.add(n);
  }
  return out.join(' ');
}
