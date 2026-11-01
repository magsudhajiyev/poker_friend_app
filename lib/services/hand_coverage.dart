/// Pure "how much of the session did we capture" maths for the
/// `session_ended` analytics event.
class SessionCoverage {
  SessionCoverage._();

  /// Rough live-table pace used to estimate hands dealt.
  static const double handsPerHour = 30;

  /// Returns the props merged into `session_ended`.
  ///
  /// `hands_logged` and `flags_open` are always present. `est_dealt`
  /// (minutes / 60 * 30) and `coverage` ((handsLogged + foldTicks) / est_dealt,
  /// capped at 1.0, 2 decimals) are present only for live sessions with a
  /// positive duration.
  static Map<String, Object> compute({
    required int handsLogged,
    required int foldTicks,
    required int flagsOpen,
    required int sessionMinutes,
    required bool isLive,
  }) {
    final out = <String, Object>{
      'hands_logged': handsLogged,
      'flags_open': flagsOpen,
    };
    if (!isLive || sessionMinutes <= 0) return out;
    final est = sessionMinutes / 60 * handsPerHour;
    final raw = (handsLogged + foldTicks) / est;
    out['est_dealt'] = est.round();
    out['coverage'] = (raw.clamp(0.0, 1.0) * 100).round() / 100;
    return out;
  }
}
