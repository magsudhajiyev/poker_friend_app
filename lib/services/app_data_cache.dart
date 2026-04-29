import 'package:shared_preferences/shared_preferences.dart';

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
  static bool _clubDataDirty = true;
  static bool _statsDataDirty = true;

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

  // ── Club screen cached data ───────────────────────────────────
  static String? _cachedClubId;
  static bool? cachedIsAdmin;
  static int? cachedMemberCount;

  // ── Statistics screen cached data ─────────────────────────────
  static Map<String, dynamic>? cachedOverallStats;

  // ── Dirty markers (called from write points) ─────────────────────
  static void markHomeDirty() => _homeDataDirty = true;
  static void markOpponentsDirty() => _opponentsDataDirty = true;
  static void markOpponentHandsDirty() => _opponentHandsDirty = true;
  static void markSessionsDirty() => _sessionsDataDirty = true;
  static void markClubDirty() => _clubDataDirty = true;
  static void markStatsDirty() => _statsDataDirty = true;

  static void markAllDirty() {
    _homeDataDirty = true;
    _opponentsDataDirty = true;
    _opponentHandsDirty = true;
    _sessionsDataDirty = true;
    _clubDataDirty = true;
    _statsDataDirty = true;
  }

  // ── Check & clear ────────────────────────────────────────────────
  static bool get isHomeDirty => _homeDataDirty;
  static bool get isOpponentsDirty => _opponentsDataDirty;
  static bool get isOpponentHandsDirty => _opponentHandsDirty;
  static bool get isSessionsDirty => _sessionsDataDirty;
  static bool get isClubDirty => _clubDataDirty;
  static bool get isStatsDirty => _statsDataDirty;
  static bool get hasStatsCacheData => cachedOverallStats != null;

  static bool get hasHomeCacheData =>
      cachedBankroll != null && cachedPlayerStats != null;

  static bool get hasClubCacheData =>
      _cachedClubId != null && cachedIsAdmin != null && cachedMemberCount != null;

  static void clearHomeDirty() => _homeDataDirty = false;
  static void clearOpponentsDirty() => _opponentsDataDirty = false;
  static void clearOpponentHandsDirty() => _opponentHandsDirty = false;
  static void clearSessionsDirty() => _sessionsDataDirty = false;
  static void clearClubDirty() => _clubDataDirty = false;
  static void clearStatsDirty() => _statsDataDirty = false;

  /// Call when entering a club screen — invalidates cache if club changed.
  static void setClubContext(String clubId) {
    if (_cachedClubId != clubId) {
      cachedIsAdmin = null;
      cachedMemberCount = null;
      _clubDataDirty = true;
      _cachedClubId = clubId;
    }
  }

  // ── SharedPreferences persistence (survives hot restart) ─────────
  static Future<void> persistAdminStatus(String clubId, bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('club_admin_$clubId', isAdmin);
  }

  static Future<bool?> getPersistedAdminStatus(String clubId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('club_admin_$clubId');
  }

  // ── Full reset (logout, account switch) ──────────────────────────
  static void clearAll() {
    _homeDataDirty = true;
    _opponentsDataDirty = true;
    _opponentHandsDirty = true;
    _sessionsDataDirty = true;
    _clubDataDirty = true;
    _statsDataDirty = true;

    cachedBankroll = null;
    cachedBankrollGoal = null;
    cachedBankrollProgress = null;
    cachedPlayerStats = null;
    cachedRecentSessions = null;
    cachedEarningsData = null;
    cachedUpcomingEvents = null;
    cachedUserName = null;
    cachedSessions = null;
    _cachedClubId = null;
    cachedIsAdmin = null;
    cachedMemberCount = null;
    cachedOverallStats = null;
  }
}
