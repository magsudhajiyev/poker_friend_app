import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Resolves a coach persona to a small, round-ready PNG on disk, so a local
/// notification can show the coach as its large icon ("emoji-sized" coach).
///
/// `flutter_local_notifications` large icons need a FILE PATH (or drawable),
/// not a bundle asset path — so the mascot asset is copied to the cache dir
/// once and reused. The hosted copies (finaltable.io/email/coach-*.png) are
/// what the SERVER push uses via FCM imageUrl; this is the on-device path for
/// device-scheduled + tester pushes.
class CoachIconService {
  CoachIconService._();

  /// coach id (coach_persona.dart) → mascot asset. Uses the 'happy' faces —
  /// friendly and on-brand for a reminder. Unknown/neutral → no icon (null),
  /// so the notification falls back to the app's small icon.
  static const Map<String, String> _asset = {
    'grinder': 'assets/mascots/grinder_happy.png',
    'professor': 'assets/mascots/professor_happy.png',
    'nova': 'assets/mascots/nova_happy.png',
  };

  /// Public URLs for the SERVER (FCM) path — the mascots are already hosted
  /// for the email template. Keep in sync with public/email/coach-*.png.
  static const Map<String, String> coachImageUrl = {
    'grinder': 'https://finaltable.io/email/coach-duke.png',
    'professor': 'https://finaltable.io/email/coach-vega.png',
    'nova': 'https://finaltable.io/email/coach-nova.png',
  };

  static final Map<String, String> _cachedPaths = {};

  /// Returns a file path to the coach's mascot PNG for use as a notification
  /// large icon, copying it out of the bundle on first use. Returns null for
  /// the neutral/unknown voice or on any failure (caller falls back to the
  /// app icon — a missing coach icon must never break the notification).
  static Future<String?> largeIconPath(String? coachId) async {
    final asset = _asset[coachId];
    if (asset == null) return null;
    if (_cachedPaths.containsKey(coachId)) return _cachedPaths[coachId];
    try {
      final dir = await getApplicationCacheDirectory();
      final file = File('${dir.path}/coach_$coachId.png');
      if (!await file.exists()) {
        final bytes = await rootBundle.load(asset);
        await file.writeAsBytes(bytes.buffer
            .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      }
      _cachedPaths[coachId!] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
