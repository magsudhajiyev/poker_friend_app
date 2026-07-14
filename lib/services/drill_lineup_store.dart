import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/drill_models.dart';
import 'auth_service.dart';

/// Persists saved drill table lineups locally. Training data never touches
/// Firestore or the real session/stats stores.
class DrillLineupStore {
  DrillLineupStore._();

  static String _key() {
    final uid = AuthService.currentUser?.uid;
    return uid != null ? 'training_drill_lineups_$uid' : 'training_drill_lineups';
  }

  static const maxLineups = 20;

  static Future<List<DrillLineup>> getLineups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key());
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => DrillLineup.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Inserts or replaces (by id) and persists. Newest first.
  static Future<void> saveLineup(DrillLineup lineup) async {
    final lineups = await getLineups();
    lineups.removeWhere((l) => l.id == lineup.id);
    lineups.insert(0, lineup);
    while (lineups.length > maxLineups) {
      lineups.removeLast();
    }
    await _persist(lineups);
  }

  static Future<void> deleteLineup(String id) async {
    final lineups = await getLineups();
    lineups.removeWhere((l) => l.id == id);
    await _persist(lineups);
  }

  static Future<void> _persist(List<DrillLineup> lineups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key(), jsonEncode(lineups.map((l) => l.toJson()).toList()));
  }
}
