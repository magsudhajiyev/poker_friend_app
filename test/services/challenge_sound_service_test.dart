import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poker_logger/models/drill_models.dart';
import 'package:poker_logger/services/challenge_sound_service.dart';

/// Daily Challenge SFX: an independent, default-ON toggle that persists;
/// playback is fire-and-forget and never throws (even with no audio plugin
/// in the test host).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The audioplayers plugin has no implementation in the VM test host.
  // Stub its method channels so play calls RESOLVE instead of rejecting —
  // that exercises the real no-throw path rather than skipping it.
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() {
    for (final name in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (call) async => null);
    }
  });

  setUp(() {
    ChallengeSoundService.debugReset();
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to ON when no preference is stored', () async {
    await ChallengeSoundService.loadEnabled();
    expect(ChallengeSoundService.enabled, isTrue);
  });

  test('setEnabled persists and round-trips', () async {
    await ChallengeSoundService.setEnabled(false);
    expect(ChallengeSoundService.enabled, isFalse);

    ChallengeSoundService.debugReset();
    await ChallengeSoundService.loadEnabled();
    expect(ChallengeSoundService.enabled, isFalse,
        reason: 'the stored OFF survives a reload');
  });

  test('reads a stored ON preference', () async {
    SharedPreferences.setMockInitialValues({'sound_effects_enabled': true});
    await ChallengeSoundService.loadEnabled();
    expect(ChallengeSoundService.enabled, isTrue);
  });

  test('independent of the coach-voice mute key', () async {
    // Muting the coach voice must NOT mute the SFX — different pref keys.
    SharedPreferences.setMockInitialValues({'coach_voice_enabled': false});
    await ChallengeSoundService.loadEnabled();
    expect(ChallengeSoundService.enabled, isTrue);
  });

  test('playVerdict / playComplete never throw (fire-and-forget)', () async {
    // No audio plugin in the test host — calls must swallow the failure.
    await ChallengeSoundService.playVerdict(DrillGrade.correct);
    await ChallengeSoundService.playVerdict(DrillGrade.ok);
    await ChallengeSoundService.playVerdict(DrillGrade.mistake);
    await ChallengeSoundService.playComplete();
  });

  test('muted service skips playback without throwing', () async {
    await ChallengeSoundService.setEnabled(false);
    await ChallengeSoundService.playVerdict(DrillGrade.mistake);
    await ChallengeSoundService.playComplete();
  });
}
