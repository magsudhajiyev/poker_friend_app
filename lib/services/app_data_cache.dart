/// Lightweight static cache with dirty flags for app-wide data.
///
/// Screens check dirty flags before loading: if cache exists and is clean,
/// serve from cache (instant). Otherwise fetch fresh, store, and clear flag.
///
/// Write points (saveHand, endSession, bankroll changes, opponent CRUD)
/// call the appropriate `mark*Dirty()` method so the next screen visit
/// fetches fresh data.
class AppDataCache {
  // ── Dirty flags ──────────────────────────────────────────────────
  static bool _homeDataDirty = true;
  static bool _opponentsDataDirty = true;
  static bool _opponentHandsDirty = true;
  static bool _sessionsDataDirty = true;

  // ── Home screen cached data ──────────────────────────────────────
  static double? cachedBankroll;
  static double? cachedBankrollGoal;
  static double? cachedBankrollProgress;
  static Map<String, dynamic>? cachedPlayerStats;
  static List<Map<String, dynamic>>? cachedRecentSessions;
  static Map<String, dynamic>? cachedEarningsData;
  static List<dynamic>? cachedUpcomingEvents;
  static String? cachedUserName;

  // ── Session history cached data ─────────────────────────────────
  static List<Map<String, dynamic>>? cachedSessions;

  // ── Dirty markers (called from write points) ─────────────────────
  static void markHomeDirty() => _homeDataDirty = true;
  static void markOpponentsDirty() => _opponentsDataDirty = true;
  static void markOpponentHandsDirty() => _opponentHandsDirty = true;
  static void markSessionsDirty() => _sessionsDataDirty = true;

  static void markAllDirty() {
    _homeDataDirty = true;
    _opponentsDataDirty = true;
    _opponentHandsDirty = true;
    _sessionsDataDirty = true;
  }

  // ── Check & clear ────────────────────────────────────────────────
  static bool get isHomeDirty => _homeDataDirty;
  static bool get isOpponentsDirty => _opponentsDataDirty;
  static bool get isOpponentHandsDirty => _opponentHandsDirty;
  static bool get isSessionsDirty => _sessionsDataDirty;

  static bool get hasHomeCacheData =>
      cachedBankroll != null && cachedPlayerStats != null;

  static void clearHomeDirty() => _homeDataDirty = false;
  static void clearOpponentsDirty() => _opponentsDataDirty = false;
  static void clearOpponentHandsDirty() => _opponentHandsDirty = false;
  static void clearSessionsDirty() => _sessionsDataDirty = false;

  // ── Full reset (logout, account switch) ──────────────────────────
  static void clearAll() {
    _homeDataDirty = true;
    _opponentsDataDirty = true;
    _opponentHandsDirty = true;
    _sessionsDataDirty = true;

    cachedBankroll = null;
    cachedBankrollGoal = null;
    cachedBankrollProgress = null;
    cachedPlayerStats = null;
    cachedRecentSessions = null;
    cachedEarningsData = null;
    cachedUpcomingEvents = null;
    cachedUserName = null;
    cachedSessions = null;
  }
}
