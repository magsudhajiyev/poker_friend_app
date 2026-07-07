import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/auth_service.dart';

/// Apple sign-in name handling: the private-relay email's random local part
/// must never be shown or stored as a display name.
void main() {
  const relay = 'x7kq2mfd9a@privaterelay.appleid.com';

  group('isPrivateRelayEmail', () {
    test('detects Apple private-relay addresses (case-insensitive)', () {
      expect(AuthService.isPrivateRelayEmail(relay), isTrue);
      expect(
          AuthService.isPrivateRelayEmail(
              'ABC@PRIVATERELAY.APPLEID.COM'),
          isTrue);
    });

    test('regular emails and null are not relay addresses', () {
      expect(AuthService.isPrivateRelayEmail('magsud@gmail.com'), isFalse);
      expect(AuthService.isPrivateRelayEmail(null), isFalse);
      expect(AuthService.isPrivateRelayEmail(''), isFalse);
    });
  });

  group('isPlaceholderNameFor', () {
    test('empty or null names are placeholders', () {
      expect(AuthService.isPlaceholderNameFor(null, 'a@b.com'), isTrue);
      expect(AuthService.isPlaceholderNameFor('', 'a@b.com'), isTrue);
      expect(AuthService.isPlaceholderNameFor('   ', 'a@b.com'), isTrue);
    });

    test('the relay token itself is a placeholder (the reported bug)', () {
      expect(
          AuthService.isPlaceholderNameFor('x7kq2mfd9a', relay), isTrue);
      expect(
          AuthService.isPlaceholderNameFor('X7KQ2MFD9A', relay), isTrue);
    });

    test('real names are never placeholders', () {
      expect(AuthService.isPlaceholderNameFor('Magsud', relay), isFalse);
      expect(
          AuthService.isPlaceholderNameFor('Magsud Hajiyev', 'a@b.com'),
          isFalse);
    });

    test('a name matching a NON-relay email local part is fine', () {
      // e.g. someone actually called "magsud" with magsud@gmail.com
      expect(
          AuthService.isPlaceholderNameFor('magsud', 'magsud@gmail.com'),
          isFalse);
    });
  });

  group('fallbackDisplayNameFor', () {
    test('keeps a real display name', () {
      expect(AuthService.fallbackDisplayNameFor('Magsud', relay), 'Magsud');
    });

    test('non-relay email local part is an acceptable fallback', () {
      expect(AuthService.fallbackDisplayNameFor(null, 'magsud@gmail.com'),
          'magsud');
      expect(AuthService.fallbackDisplayNameFor('', 'magsud@gmail.com'),
          'magsud');
    });

    test('relay email NEVER leaks its token — falls back to Player', () {
      expect(AuthService.fallbackDisplayNameFor(null, relay), 'Player');
      expect(AuthService.fallbackDisplayNameFor('', relay), 'Player');
      // Stored relay token gets replaced too.
      expect(AuthService.fallbackDisplayNameFor('x7kq2mfd9a', relay), 'Player');
    });

    test('no name and no email yields Player', () {
      expect(AuthService.fallbackDisplayNameFor(null, null), 'Player');
      expect(AuthService.fallbackDisplayNameFor(null, ''), 'Player');
    });
  });
}
