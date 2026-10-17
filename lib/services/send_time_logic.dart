/// Pure send-time math shared by the client and documented for the server
/// scheduler (the Cloud Function reimplements these in TS). Kept Dart-side so
/// the arithmetic is unit-tested in one place.
///
/// Everything is integer hour arithmetic on a UTC hour + a timezone offset in
/// MINUTES (what the app captures as `notif.tzOffsetMinutes`). No timezone
/// database is needed on either side; DST is handled because the client
/// rewrites the offset on every prefs load.
library;

class SendTimeLogic {
  SendTimeLogic._();

  /// Convert a UTC hour (0–23) to the user's local hour given their offset in
  /// minutes (east-of-UTC positive, e.g. CET winter = 60). Any offset and any
  /// hour normalize into 0–23.
  static int localHour(int utcHour, int tzOffsetMinutes) {
    final totalMinutes = utcHour * 60 + tzOffsetMinutes;
    final h = (totalMinutes ~/ 60) % 24;
    return h < 0 ? h + 24 : h;
  }

  /// Whether to fire at [utcHourNow] for a user whose best LOCAL active hour
  /// is [localActiveHour], optionally landing [leadHours] before they usually
  /// open (so the push is waiting when they do). Returns true when the user's
  /// current local hour equals their target send hour.
  static bool isInSendWindow({
    required int utcHourNow,
    required int activeHourUtc,
    required int tzOffsetMinutes,
    int leadHours = 0,
  }) {
    final localNow = localHour(utcHourNow, tzOffsetMinutes);
    final localActive = localHour(activeHourUtc, tzOffsetMinutes);
    final target = ((localActive - leadHours) % 24 + 24) % 24;
    return localNow == target;
  }
}
