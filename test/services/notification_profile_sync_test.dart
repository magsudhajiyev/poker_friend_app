import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/notification_profile_sync.dart';

void main() {
  const supported = ['en', 'de', 'ru'];

  group('effectiveLocaleCode', () {
    test('the Settings choice wins over the device language', () {
      expect(
          NotificationProfileSync.effectiveLocaleCode(
              const Locale('de'), const Locale('ru'), supported),
          'de');
    });

    test('no choice → device language', () {
      expect(
          NotificationProfileSync.effectiveLocaleCode(
              null, const Locale('ru', 'RU'), supported),
          'ru');
    });

    test('unsupported language → English', () {
      expect(
          NotificationProfileSync.effectiveLocaleCode(
              null, const Locale('ja'), supported),
          'en');
      // An unsupported explicit choice falls through to the device language.
      expect(
          NotificationProfileSync.effectiveLocaleCode(
              const Locale('ja'), const Locale('de'), supported),
          'de');
    });
  });

  group('needsWrite', () {
    test('first run and any change write; same pair does not', () {
      expect(NotificationProfileSync.needsWrite(null, 60, 'en'), isTrue);
      expect(NotificationProfileSync.needsWrite('60|en', 60, 'en'), isFalse);
      expect(NotificationProfileSync.needsWrite('60|en', 120, 'en'), isTrue);
      expect(NotificationProfileSync.needsWrite('60|en', 60, 'de'), isTrue);
    });
  });
}
