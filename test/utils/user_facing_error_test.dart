import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/utils/user_facing_error.dart';

/// UserFacingError.message: raw exceptions never reach the UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('connectivity errors', () {
    test('SocketException and lookup failures → no-connection message', () {
      expect(UserFacingError.message(const SocketException('failed')),
          contains('internet'));
      expect(
          UserFacingError.message(Exception(
              'SocketException: Failed host lookup: api.example.com')),
          contains('internet'));
      expect(
          UserFacingError.message('[firebase_auth/network-request-failed] x'),
          contains('internet'));
    });

    test('timeouts → timeout message', () {
      expect(UserFacingError.message(TimeoutException('30s')),
          contains('timed out'));
    });
  });

  group('permission errors', () {
    test('firestore permission-denied → not-authorized message', () {
      expect(
          UserFacingError.message(
              Exception('[cloud_firestore/permission-denied] Missing rights')),
          contains('permission'));
    });
  });

  group('server errors', () {
    test('the export failure from the report → friendly server message', () {
      final msg = UserFacingError.message(Exception(
          'Server returned 502: {"detail":"Email provider error (401)"}'));
      expect(msg, contains('our side'));
      expect(msg, isNot(contains('502')));
      expect(msg, isNot(contains('401')));
      expect(msg, isNot(contains('{')));
    });

    test('401/403 from backend → not-authorized', () {
      expect(UserFacingError.message(Exception('Server returned 401: nope')),
          contains('permission'));
    });
  });

  group('deliberate human messages pass through', () {
    test('AuthService-style thrown strings are preserved', () {
      expect(UserFacingError.message('No account found with this email'),
          'No account found with this email');
      expect(
          UserFacingError.message('Failed to delete account. Please try again.'),
          'Failed to delete account. Please try again.');
    });

    test('technical strings do NOT pass through', () {
      expect(UserFacingError.message('Exception: something broke badly'),
          isNot(contains('Exception')));
      expect(UserFacingError.message('{"detail":"boom"}'),
          isNot(contains('{')));
    });
  });

  group('fallback', () {
    test('unknown errors → generic message, never raw toString', () {
      final msg = UserFacingError.message(StateError('widget tree corrupted'));
      expect(msg, isNot(contains('StateError')));
      expect(msg, isNot(contains('widget tree')));
      expect(msg.length, greaterThan(10));
    });

    test('null-safe', () {
      expect(UserFacingError.message(null), isNotEmpty);
    });
  });
}
