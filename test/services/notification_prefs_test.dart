import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/notification_prefs_service.dart';

/// NotificationPrefs pure logic: defaults, (de)serialization, the master
/// gate, and the midnight-wrapping quiet-hours window.
void main() {
  group('defaults', () {
    test('all categories on, 22:00–08:00 quiet', () {
      const p = NotificationPrefs();
      expect(p.master, isTrue);
      for (final c in NotifCategory.values) {
        expect(p.categoryEnabled(c), isTrue, reason: '$c default-on');
      }
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
}
