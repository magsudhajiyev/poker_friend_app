/// Per-seat stack provenance of a single-hand log (single-hand setup v2, D10).
///
/// A hand's `stackSources` map is seat -> [kStackSet] (the player entered the
/// stack) or [kStackDefault] (assumed equal to the hero's). The field is
/// ABSENT on full sessions and on hands saved before it existed: absent means
/// "not known", never "assumed".
const String kStackSet = 'set';
const String kStackDefault = 'default';

/// True only when the hand explicitly marks [seat]'s stack as `default`.
bool isAssumedStack(Map<dynamic, dynamic> hand, int seat) =>
    parseStackSources(hand['stackSources'])?[seat] == kStackDefault;

/// Tolerant reader: [raw] is a seat-keyed map (string or int keys) as stored
/// in Firestore, or a JSON string as stored in SQLite. Null when absent,
/// empty or unusable; unknown values are dropped.
Map<int, String>? parseStackSources(Object? raw) {
  if (raw is! Map) return null;
  final out = <int, String>{};
  raw.forEach((k, v) {
    final seat = k is int ? k : int.tryParse('$k');
    if (seat != null && (v == kStackSet || v == kStackDefault)) {
      out[seat] = v as String;
    }
  });
  return out.isEmpty ? null : out;
}

/// Firestore / JSON shape: string seat keys. Null when [sources] is empty.
Map<String, String>? stackSourcesToMap(Map<int, String>? sources) =>
    sources == null || sources.isEmpty
        ? null
        : {for (final e in sources.entries) '${e.key}': e.value};
