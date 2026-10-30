import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/hand_display_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HandDisplayPrefs.debugReset();
  });

  test('defaults to money display', () async {
    expect(await HandDisplayPrefs.load(), isFalse);
    expect(HandDisplayPrefs.showBB, isFalse);
  });

  test('toggle is visible at once to the next screen instance', () async {
    await HandDisplayPrefs.load();
    final pending = HandDisplayPrefs.setShowBB(true);
    expect(HandDisplayPrefs.showBB, isTrue); // sync, before write completes
    await pending;
  });

  test('survives an app restart (cache cleared, storage kept)', () async {
    await HandDisplayPrefs.setShowBB(true);
    HandDisplayPrefs.debugReset();
    expect(HandDisplayPrefs.showBB, isFalse);
    expect(await HandDisplayPrefs.load(), isTrue);
    expect(HandDisplayPrefs.showBB, isTrue);
  });

  test('switching back to money persists', () async {
    await HandDisplayPrefs.setShowBB(true);
    await HandDisplayPrefs.setShowBB(false);
    HandDisplayPrefs.debugReset();
    expect(await HandDisplayPrefs.load(), isFalse);
  });
}
