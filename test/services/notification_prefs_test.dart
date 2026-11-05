import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/notification_prefs_service.dart';

/// NotificationPrefs pure logic: defaults, (de)serialization, the master
/// gate, and the midnight-wrapping quiet-hours window.
void main() {
  group('defaults', () {
    test('all categories on, 22:00–08:00 quiet', () {
      const p = NotificationPrefs();
      expect(p.master, isTrue);
      for (final c in NotifCategory.values.where((c) => c != NotifCategory.offers)) {
        expect(p.categoryEnabled(c), isTrue, reason: '$c default-on');
      }
      expect(p.categoryEnabled(NotifCategory.offers), isFalse,
          reason: 'offers is opt-in: missing = OFF');
      expect(p.quietStartLocal, 22);
      expect(p.quietEndLocal, 8);
    });

    test('fromMap(null) gives defaults; junk hours clamp to defaults', () {
      expect(NotificationPrefs.fromMap(null).master, isTrue);
      final p = NotificationPrefs.fromMap(
          {'quietStartLocal': 99, 'quietEndLocal': -3});
      expect(p.quietStartLocal, 22);
      expect(p.quietEndLocal, 8);
    });
  });

  group('master gate', () {
    test('master off kills every category even when individually on', () {
      const p = NotificationPrefs(master: false);
      for (final c in NotifCategory.values) {
        expect(p.categoryEnabled(c), isFalse);
      }
    });

    test('single category off mutes only that category', () {
      const p = NotificationPrefs(leaderboard: false);
      expect(p.categoryEnabled(NotifCategory.leaderboard), isFalse);
      expect(p.categoryEnabled(NotifCategory.streak), isTrue);
      expect(p.categoryEnabled(NotifCategory.reengage), isTrue);
    });
  });

  group('quiet hours', () {
    test('default window wraps midnight: 22→8', () {
      const p = NotificationPrefs();
      expect(p.isQuietHour(22), isTrue);
      expect(p.isQuietHour(23), isTrue);
      expect(p.isQuietHour(0), isTrue);
      expect(p.isQuietHour(7), isTrue);
      expect(p.isQuietHour(8), isFalse, reason: 'end is exclusive');
      expect(p.isQuietHour(12), isFalse);
      expect(p.isQuietHour(21), isFalse);
    });

    test('non-wrapping window: 13→15', () {
      const p = NotificationPrefs(quietStartLocal: 13, quietEndLocal: 15);
      expect(p.isQuietHour(12), isFalse);
      expect(p.isQuietHour(13), isTrue);
      expect(p.isQuietHour(14), isTrue);
      expect(p.isQuietHour(15), isFalse);
    });

    test('zero-width window = quiet hours off', () {
      const p = NotificationPrefs(quietStartLocal: 9, quietEndLocal: 9);
      for (var h = 0; h < 24; h++) {
        expect(p.isQuietHour(h), isFalse);
      }
    });
  });

  group('round-trip', () {
    test('toMap → fromMap preserves everything', () {
      const p = NotificationPrefs(
        master: true,
        streak: false,
        leaderboard: true,
        reengage: false,
        quietStartLocal: 23,
        quietEndLocal: 7,
        tzOffsetMinutes: 120,
      );
      final back = NotificationPrefs.fromMap(p.toMap());
      expect(back.streak, isFalse);
      expect(back.reengage, isFalse);
      expect(back.leaderboard, isTrue);
      expect(back.quietStartLocal, 23);
      expect(back.quietEndLocal, 7);
      expect(back.tzOffsetMinutes, 120);
    });

    test('tzOffsetMinutes omitted from map when null (merge-safe)', () {
      expect(const NotificationPrefs().toMap().containsKey('tzOffsetMinutes'),
          isFalse);
    });
  });

  group('offers consent', () {
    test('missing offers = OFF and nothing is written until a choice exists',
        () {
      final p = NotificationPrefs.fromMap({'master': true});
      expect(p.offers, isFalse);
      expect(p.offersConsentAt, isNull);
      expect(p.toMap().containsKey('offers'), isFalse,
          reason: 'a stale save must not write offers=false over a choice');
    });

    test('offers requires the master switch too', () {
      const on = NotificationPrefs(offers: true);
      expect(on.categoryEnabled(NotifCategory.offers), isTrue);
      const muted = NotificationPrefs(master: false, offers: true);
      expect(muted.categoryEnabled(NotifCategory.offers), isFalse);
    });

    test('a recorded choice is serialized and round-trips', () {
      final at = DateTime(2026, 11, 5, 12);
      final m = NotificationPrefs(offers: true, offersConsentAt: at).toMap();
      expect(m['offers'], isTrue);
      final back = NotificationPrefs.fromMap(m);
      expect(back.offers, isTrue);
      expect(back.offersConsentAt, at);
    });

    test('an explicit opt-out is serialized too', () {
      final m = NotificationPrefs(offersConsentAt: DateTime(2026, 11, 5))
          .toMap();
      expect(m['offers'], isFalse);
    });
  });

  group('per-account cache', () {
    tearDown(NotificationPrefsService.debugReset);

    test('cacheServes only for the same signed-in uid', () {
      expect(NotificationPrefsService.cacheServes(true, 'a', 'a'), isTrue);
      expect(NotificationPrefsService.cacheServes(true, 'a', 'b'), isFalse);
      expect(NotificationPrefsService.cacheServes(true, 'a', null), isFalse);
      expect(NotificationPrefsService.cacheServes(false, 'a', 'a'), isFalse);
    });

    test('user B does not inherit user A\'s offers consent', () async {
      NotificationPrefsService.debugFetch = (uid) async => uid == 'a'
          ? {'offers': true, 'offersConsentAt': null, 'master': true}
          : null;
      NotificationPrefsService.debugUid = 'a';
      final a = await NotificationPrefsService.ensureLoaded();
      expect(a.offers, isTrue);

      NotificationPrefsService.debugUid = 'b';
      final b = await NotificationPrefsService.ensureLoaded();
      expect(b.offers, isFalse);
      expect(b.offersConsentAt, isNull);
    });

    test('a failed load for B leaves defaults, not A\'s prefs', () async {
      NotificationPrefsService.debugFetch =
          (uid) async => {'offers': true, 'master': true};
      NotificationPrefsService.debugUid = 'a';
      await NotificationPrefsService.ensureLoaded();

      NotificationPrefsService.debugFetch = (uid) async => throw 'offline';
      NotificationPrefsService.debugUid = 'b';
      final b = await NotificationPrefsService.ensureLoaded();
      expect(b.offers, isFalse);
      expect(NotificationPrefsService.current.offers, isFalse);
    });

    test('same user is served from the cache without a second read', () async {
      var reads = 0;
      NotificationPrefsService.debugFetch = (uid) async {
        reads++;
        return {'master': true};
      };
      NotificationPrefsService.debugUid = 'a';
      await NotificationPrefsService.ensureLoaded();
      await NotificationPrefsService.ensureLoaded();
      expect(reads, 1);
    });

    test('sign-out forgets the cache', () async {
      NotificationPrefsService.debugFetch =
          (uid) async => {'offers': true, 'master': true};
      NotificationPrefsService.debugUid = 'a';
      await NotificationPrefsService.ensureLoaded();
      NotificationPrefsService.onSignOut();
      expect(NotificationPrefsService.current.offers, isFalse);
      expect(NotificationPrefsService.debugLoaded, isFalse);
    });
  });
}
