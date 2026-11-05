import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'auth_service.dart';
import 'logger_service.dart';

/// Engagement-notification categories a user can mute independently.
enum NotifCategory { streak, leaderboard, reengage, offers }

/// One user's engagement-notification preferences — the `notif` map on
/// `users/{uid}`. Pure value type; (de)serialization is unit-testable.
///
/// Defaults are ALL-ON (except `offers`, which is opt-in: missing = OFF, per
/// Apple's explicit-consent rule) with 22:00–08:00 quiet hours (the Duolingo-model
/// guardrail; the streak-saver is exempt from quiet hours by policy, which
/// the SCHEDULER enforces, not this model).
class NotificationPrefs {
  final bool master;
  final bool streak;
  final bool leaderboard;
  final bool reengage;
  final int quietStartLocal; // hour 0–23
  final int quietEndLocal; // hour 0–23

  /// Device-reported offset so the server scheduler can convert the user's
  /// local hours to UTC. Written on every load (cheap, keeps DST fresh).
  final int? tzOffsetMinutes;

  /// Opt-in for offer pushes (trial recap / missed day / paywall return).
  /// Missing = OFF. [offersConsentAt] is set once the user has made a choice
  /// either way; only then are the two fields written by [toMap].
  final bool offers;
  final DateTime? offersConsentAt;

  const NotificationPrefs({
    this.master = true,
    this.streak = true,
    this.leaderboard = true,
    this.reengage = true,
    this.quietStartLocal = 22,
    this.quietEndLocal = 8,
    this.tzOffsetMinutes,
    this.offers = false,
    this.offersConsentAt,
  });

  bool categoryEnabled(NotifCategory c) =>
      master &&
      switch (c) {
        NotifCategory.streak => streak,
        NotifCategory.leaderboard => leaderboard,
        NotifCategory.reengage => reengage,
        NotifCategory.offers => offers,
      };

  /// Whether [hourLocal] (0–23) falls inside the quiet window. Handles
  /// windows that wrap midnight (22 → 8) and same-hour (= disabled) windows.
  bool isQuietHour(int hourLocal) {
    final h = hourLocal % 24;
    if (quietStartLocal == quietEndLocal) return false; // zero-width = off
    if (quietStartLocal < quietEndLocal) {
      return h >= quietStartLocal && h < quietEndLocal;
    }
    return h >= quietStartLocal || h < quietEndLocal; // wraps midnight
  }

  NotificationPrefs copyWith({
    bool? master,
    bool? streak,
    bool? leaderboard,
    bool? reengage,
    int? quietStartLocal,
    int? quietEndLocal,
    int? tzOffsetMinutes,
    bool? offers,
    DateTime? offersConsentAt,
  }) =>
      NotificationPrefs(
        master: master ?? this.master,
        streak: streak ?? this.streak,
        leaderboard: leaderboard ?? this.leaderboard,
        reengage: reengage ?? this.reengage,
        quietStartLocal: quietStartLocal ?? this.quietStartLocal,
        quietEndLocal: quietEndLocal ?? this.quietEndLocal,
        tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
        offers: offers ?? this.offers,
        offersConsentAt: offersConsentAt ?? this.offersConsentAt,
      );

  Map<String, dynamic> toMap() => {
        'master': master,
        'streak': streak,
        'leaderboard': leaderboard,
        'reengage': reengage,
        'quietStartLocal': quietStartLocal,
        'quietEndLocal': quietEndLocal,
        if (tzOffsetMinutes != null) 'tzOffsetMinutes': tzOffsetMinutes,
        if (offersConsentAt != null) ...{
          'offers': offers,
          'offersConsentAt': Timestamp.fromDate(offersConsentAt!),
        },
      };

  factory NotificationPrefs.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const NotificationPrefs();
    int hour(dynamic v, int fallback) {
      final n = (v as num?)?.toInt() ?? fallback;
      return (n >= 0 && n <= 23) ? n : fallback;
    }

    return NotificationPrefs(
      master: m['master'] != false,
      streak: m['streak'] != false,
      leaderboard: m['leaderboard'] != false,
      reengage: m['reengage'] != false,
      quietStartLocal: hour(m['quietStartLocal'], 22),
      quietEndLocal: hour(m['quietEndLocal'], 8),
      tzOffsetMinutes: (m['tzOffsetMinutes'] as num?)?.toInt(),
      offers: m['offers'] == true,
      offersConsentAt: switch (m['offersConsentAt']) {
        Timestamp t => t.toDate(),
        _ => null,
      },
    );
  }
}

/// Loads/saves [NotificationPrefs] on `users/{uid}.notif`. Firestore is the
/// source of truth (the server scheduler reads the same map); a cached copy
/// serves synchronous gating on the client. Fire-and-forget contract on
/// writes — preferences must never break the app.
class NotificationPrefsService {
  NotificationPrefsService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static NotificationPrefs _cached = const NotificationPrefs();
  static bool _loaded = false;

  /// The uid the cache belongs to: a different (or no) signed-in user must
  /// never inherit another account's prefs (notably `offers` consent).
  static String? _loadedUid;

  /// Test seams: replace the signed-in uid / the Firestore `notif` read.
  @visibleForTesting
  static String? debugUid;
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function(String uid)? debugFetch;

  static String? get _uid => debugUid ?? AuthService.currentUser?.uid;

  /// Pure: whether a cache loaded for [loadedUid] may serve [currentUid].
  static bool cacheServes(bool loaded, String? loadedUid, String? currentUid) =>
      loaded && currentUid != null && loadedUid == currentUid;

  /// Synchronous view of the last loaded prefs (defaults before [load]).
  static NotificationPrefs get current => _cached;

  /// Observable for Settings UI rebuilds.
  static final ValueNotifier<NotificationPrefs> prefs =
      ValueNotifier<NotificationPrefs>(const NotificationPrefs());

  /// The cached prefs, loading them from Firestore once per process.
  static Future<NotificationPrefs> ensureLoaded() async {
    if (cacheServes(_loaded, _loadedUid, _uid)) return _cached;
    return load();
  }

  /// Load prefs from Firestore and refresh the stored tz offset (keeps the
  /// server's local→UTC conversion current across travel/DST). Safe to call
  /// repeatedly; failures leave defaults in place.
  static Future<NotificationPrefs> load() async {
    final uid = _uid;
    if (uid == null) return _cached;
    if (_loadedUid != uid) {
      // Account switch: drop the previous user's prefs before anything else,
      // so a failed load leaves defaults (offers OFF), never A's consent.
      _cached = const NotificationPrefs();
      _loaded = false;
      _loadedUid = uid;
      prefs.value = _cached;
    }
    try {
      final Object? map;
      final fetch = debugFetch;
      if (fetch != null) {
        map = await fetch(uid);
      } else {
        final snap = await _db.collection('users').doc(uid).get();
        map = snap.data()?['notif'];
      }
      if (_loadedUid != uid) return _cached; // switched mid-read
      _cached = NotificationPrefs.fromMap(
          map is Map ? map.cast<String, dynamic>() : null);
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      if (_cached.tzOffsetMinutes != offset) {
        _cached = _cached.copyWith(tzOffsetMinutes: offset);
        if (debugFetch == null) {
          _db
            .collection('users')
            .doc(uid)
            .set({'notif': {'tzOffsetMinutes': offset}},
                SetOptions(merge: true))
            .catchError((_) {});
        }
      }
      _loaded = true;
      prefs.value = _cached;
    } catch (e) {
      LoggerService.warning('NotifPrefs: load failed: $e');
    }
    return _cached;
  }

  /// Persist updated prefs (merge — never clobbers scheduler-written fields
  /// like activeHourLocal). Updates the cache/notifier optimistically.
  static Future<void> save(NotificationPrefs updated) async {
    _cached = updated;
    prefs.value = updated;
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({'notif': updated.toMap()}, SetOptions(merge: true));
    } catch (e) {
      LoggerService.warning('NotifPrefs: save failed: $e');
    }
  }

  /// Record the user's explicit offers choice (consent prompt or Settings
  /// toggle). Merges ONLY the offers fields so a stale cached copy can never
  /// clobber other prefs. This is the one site that fires `offers_consent`.
  static Future<void> setOffers(bool enabled, {required String source}) async {
    final now = DateTime.now();
    _cached = _cached.copyWith(offers: enabled, offersConsentAt: now);
    prefs.value = _cached;
    AnalyticsService.capture(
        'offers_consent', {'granted': enabled, 'source': source});
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'notif': {
          'offers': enabled,
          'offersConsentAt': Timestamp.fromDate(now),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      LoggerService.warning('NotifPrefs: setOffers failed: $e');
    }
  }

  /// Mirror the user's chosen coach id onto `users/{uid}.notif.coachId` so
  /// the SERVER scheduler can voice pushes in their coach (the picker only
  /// stores it in SharedPreferences otherwise). Best-effort.
  static Future<void> saveCoachId(String coachId) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({'notif': {'coachId': coachId}}, SetOptions(merge: true));
    } catch (e) {
      LoggerService.warning('NotifPrefs: saveCoachId failed: $e');
    }
  }

  @visibleForTesting
  static void debugReset() {
    _cached = const NotificationPrefs();
    _loaded = false;
    _loadedUid = null;
    debugUid = null;
    debugFetch = null;
    prefs.value = _cached;
  }

  /// Sign-out: forget the cache so the next account starts from defaults.
  static void onSignOut() {
    _cached = const NotificationPrefs();
    _loaded = false;
    _loadedUid = null;
    prefs.value = _cached;
  }

  @visibleForTesting
  static bool get debugLoaded => _loaded;
}
