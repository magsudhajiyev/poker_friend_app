import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistence for the Leak Detector's investment loop (retention doc R2):
/// the single ACTIVE FOCUS leak the player committed to fixing, and the
/// permanent FIXED LEAKS shelf — the trophy case that makes progress
/// feel owned.
///
/// Storage is SharedPreferences JSON, same tier as the report snapshot.
/// All models are pure/jsonable; the diff/celebration logic lives in the
/// screen, which compares the focus goal against the fresh report.
class LeakFocusGoal {
  final String findingId;
  final String title;
  final DateTime startedAt;
  final double startValue;
  final int startSampleCount;

  const LeakFocusGoal({
    required this.findingId,
    required this.title,
    required this.startedAt,
    required this.startValue,
    required this.startSampleCount,
  });

  Map<String, dynamic> toJson() => {
        'id': findingId,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'startValue': startValue,
        'startN': startSampleCount,
      };

  static LeakFocusGoal? fromJson(dynamic json) {
    if (json is! Map) return null;
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final id = json['id'];
    final value = json['startValue'];
    if (startedAt == null || id is! String || value is! num) return null;
    return LeakFocusGoal(
      findingId: id,
      title: json['title'] as String? ?? id,
      startedAt: startedAt,
      startValue: value.toDouble(),
      startSampleCount: (json['startN'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One entry on the permanent trophy shelf.
class FixedLeak {
  final String findingId;
  final String title;
  final DateTime startedAt;
  final DateTime fixedAt;
  final double startValue;
  final double fixedValue;

  const FixedLeak({
    required this.findingId,
    required this.title,
    required this.startedAt,
    required this.fixedAt,
    required this.startValue,
    required this.fixedValue,
  });

  int get daysToFix => fixedAt.difference(startedAt).inDays;

  Map<String, dynamic> toJson() => {
        'id': findingId,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'fixedAt': fixedAt.toIso8601String(),
        'startValue': startValue,
        'fixedValue': fixedValue,
      };

  static FixedLeak? fromJson(dynamic json) {
    if (json is! Map) return null;
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final fixedAt = DateTime.tryParse(json['fixedAt'] as String? ?? '');
    final id = json['id'];
    if (startedAt == null || fixedAt == null || id is! String) return null;
    return FixedLeak(
      findingId: id,
      title: json['title'] as String? ?? id,
      startedAt: startedAt,
      fixedAt: fixedAt,
      startValue: ((json['startValue'] as num?) ?? 0).toDouble(),
      fixedValue: ((json['fixedValue'] as num?) ?? 0).toDouble(),
    );
  }
}

class LeakFocusStore {
  LeakFocusStore._();

  static const String _focusKey = 'leak_focus_goal_v1';
  static const String _fixedKey = 'leak_fixed_shelf_v1';

  static Future<LeakFocusGoal?> loadFocus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_focusKey);
      if (raw == null) return null;
      return LeakFocusGoal.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveFocus(LeakFocusGoal goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_focusKey, jsonEncode(goal.toJson()));
    } catch (_) {}
  }

  static Future<void> clearFocus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_focusKey);
    } catch (_) {}
  }

  static Future<List<FixedLeak>> loadFixed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_fixedKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (FixedLeak.fromJson(e) != null) FixedLeak.fromJson(e)!,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Appends to the shelf (newest first) and clears the focus in one go —
  /// the only way a goal leaves the focus slot with honor.
  static Future<void> recordFixed(FixedLeak fixed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadFixed();
      final updated = [fixed, ...current];
      await prefs.setString(
          _fixedKey, jsonEncode([for (final f in updated) f.toJson()]));
      await prefs.remove(_focusKey);
    } catch (_) {}
  }
}
