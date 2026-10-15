import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drill_models.dart';

/// Short sound effects for the Daily Challenge: a per-verdict cue when the
/// grade is revealed and a fanfare when the five-spot run completes.
///
/// Deliberately independent of the coach VOICE mute ([coach_voice_service])
/// — many players mute the talking coach but still want the quick feedback
/// blip. This has its own `sound_effects_enabled` toggle (default ON).
///
/// Fire-and-forget contract, like the coach voice and FCM: every call
/// swallows errors and no-ops when muted, so audio never breaks the run.
/// Assets are bundled WAVs under `assets/sounds/` (synthesized clean tones).
class ChallengeSoundService {
  ChallengeSoundService._();

  static const String _prefKey = 'sound_effects_enabled';

  static bool _enabled = true;
  static bool _prefLoaded = false;
  static bool _contextConfigured = false;

  /// One reusable low-latency player — SFX are short and never overlap
  /// meaningfully (a verdict then, much later, a completion fanfare).
  static AudioPlayer? _player;

  static const Map<DrillGrade, String> _verdictAsset = {
    DrillGrade.correct: 'sounds/correct.wav',
    DrillGrade.ok: 'sounds/ok.wav',
    DrillGrade.mistake: 'sounds/mistake.wav',
  };
  static const String _completeAsset = 'sounds/complete.wav';

  /// Current toggle state (synchronous; reflects the last loaded/ set value).
  static bool get enabled => _enabled;

  /// Load the persisted toggle once. Safe to call repeatedly.
  static Future<void> loadEnabled() async {
    if (_prefLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
    _prefLoaded = true;
  }

  /// Flip the toggle and persist it. A disabled service stops any playing
  /// cue immediately.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    _prefLoaded = true;
    if (!value) {
      try {
        await _player?.stop();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// Play the cue for a revealed [grade]. No-op when muted or on any error.
  static Future<void> playVerdict(DrillGrade grade) =>
      _play(_verdictAsset[grade]);

  /// Play the completion fanfare. No-op when muted or on any error.
  static Future<void> playComplete() => _play(_completeAsset);

  static Future<void> _play(String? asset) async {
    if (asset == null) return;
    try {
      await loadEnabled();
      if (!_enabled) return;
      await _configureContext();
      final player = _player ??= AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency);
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.9);
    } catch (_) {
      // Fire-and-forget: a failed cue must never break the challenge.
    }
  }

  /// One-time audio session config. Plays over the iOS silent switch (the
  /// player explicitly opened a sounded challenge) and ducks other audio.
  static Future<void> _configureContext() async {
    if (_contextConfigured) return;
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.duckOthers,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
    } catch (_) {}
    _contextConfigured = true;
  }

  /// Release the player (e.g. on screen dispose). Safe to call when unset.
  static Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }

  @visibleForTesting
  static void debugReset() {
    _enabled = true;
    _prefLoaded = false;
    _contextConfigured = false;
    _player = null;
  }
}
