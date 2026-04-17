import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Resolves which name to display for the current user based on
/// their useNicknameInGame preference.
class DisplayIdentityService {
  static String? _cachedUsername;
  static bool? _cachedUseNickname;
  static String? _cachedForUserId;

  /// Returns the appropriate display name for the current user.
  /// If useNicknameInGame is true and username is set, returns the username.
  /// Otherwise falls back to AuthService.userDisplayName.
  static Future<String> getDisplayIdentity() async {
    final userId = AuthService.userId;
    if (userId == null) return AuthService.userDisplayName;

    // Use cache if available for same user
    if (_cachedForUserId == userId && _cachedUseNickname != null) {
      if (_cachedUseNickname == true && _cachedUsername != null) {
        return _cachedUsername!;
      }
      return AuthService.userDisplayName;
    }

    // Fetch from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data();
      _cachedUsername = data?['username'] as String?;
      _cachedUseNickname = data?['useNicknameInGame'] as bool? ?? false;
      _cachedForUserId = userId;

      if (_cachedUseNickname == true && _cachedUsername != null) {
        return _cachedUsername!;
      }
    } catch (_) {}

    return AuthService.userDisplayName;
  }

  /// Synchronous getter for cached value (use after initial load).
  static String get cachedDisplayIdentity {
    if (_cachedUseNickname == true && _cachedUsername != null) {
      return _cachedUsername!;
    }
    return AuthService.userDisplayName;
  }

  /// Clear cache (call on sign out, username change, or toggle change).
  static void clearCache() {
    _cachedUsername = null;
    _cachedUseNickname = null;
    _cachedForUserId = null;
  }
}
