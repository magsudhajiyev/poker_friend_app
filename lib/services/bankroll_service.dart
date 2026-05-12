import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/user_stats_service.dart';
import '../services/auth_service.dart';
import 'app_data_cache.dart';

class BankrollService {
  static const String _goalKey = 'bankroll_goal';
  static const String _currentBankrollKey = 'current_bankroll';
  static const String _syncedKey = 'bankroll_synced_from_firestore';

  /// Called on login / app start. Pulls bankroll from Firestore into
  /// SharedPreferences so the rest of the app can read locally.
  /// Only overwrites local values if Firestore has data.
  static Future<void> syncFromFirestore() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Only overwrite local if Firestore has the fields
      if (data.containsKey('bankrollGoal')) {
        final goal = (data['bankrollGoal'] as num).toDouble();
        await prefs.setDouble(_goalKey, goal);
      }
      if (data.containsKey('currentBankroll')) {
        final bankroll = (data['currentBankroll'] as num).toDouble();
        await prefs.setDouble(_currentBankrollKey, bankroll);
      }

      await prefs.setBool(_syncedKey, true);
      AppDataCache.markHomeDirty();
    } catch (e) {
      debugPrint('Error syncing bankroll from Firestore: $e');
    }
  }

  /// Persist bankroll values to Firestore (fire-and-forget).
  static Future<void> _syncToFirestore({double? goal, double? bankroll}) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final updates = <String, dynamic>{};
      if (goal != null) updates['bankrollGoal'] = goal;
      if (bankroll != null) updates['currentBankroll'] = bankroll;
      if (updates.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing bankroll to Firestore: $e');
    }
  }

  // Get bankroll goal
  static Future<double> getBankrollGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_goalKey) ?? 0.0;
    } catch (e) {
      debugPrint('Error getting bankroll goal: $e');
      return 0.0;
    }
  }

  // Set bankroll goal
  static Future<void> setBankrollGoal(double goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_goalKey, goal);
      AppDataCache.markHomeDirty();
      await _syncToFirestore(goal: goal);
    } catch (e) {
      debugPrint('Error setting bankroll goal: $e');
    }
  }

  // Get current bankroll
  static Future<double> getCurrentBankroll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_currentBankrollKey) ?? 0.0;
    } catch (e) {
      debugPrint('Error getting current bankroll: $e');
      return 0.0;
    }
  }

  // Set current bankroll
  static Future<void> setCurrentBankroll(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_currentBankrollKey, amount);
      AppDataCache.markHomeDirty();
      await _syncToFirestore(bankroll: amount);
    } catch (e) {
      debugPrint('Error setting current bankroll: $e');
    }
  }

  // Add to bankroll (for session results)
  static Future<void> addToBankroll(double amount) async {
    try {
      final current = await getCurrentBankroll();
      await setCurrentBankroll(current + amount);
    } catch (e) {
      debugPrint('Error adding to bankroll: $e');
    }
  }

  // Get bankroll progress (0.0 to 1.0)
  static Future<double> getBankrollProgress() async {
    try {
      final current = await getCurrentBankroll();
      final goal = await getBankrollGoal();
      final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
      return progress;
    } catch (e) {
      debugPrint('Error calculating bankroll progress: $e');
      return 0.0;
    }
  }

  // Get remaining amount to goal
  static Future<double> getRemainingToGoal() async {
    try {
      final current = await getCurrentBankroll();
      final goal = await getBankrollGoal();
      return (goal - current).clamp(0.0, double.infinity);
    } catch (e) {
      debugPrint('Error calculating remaining to goal: $e');
      return 0.0;
    }
  }

  // Get statistics from user stats (real-time updated from hands)
  static Future<Map<String, dynamic>> getPlayerStatistics() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        return {
          'totalSessions': 0,
          'totalHours': 0.0,
          'winRate': 0.0,
          'currentStreak': 0,
          'avgWeeklyEarnings': 0.0,
          'vpip': 0.0,
          'pfr': 0.0,
          'threeBet': 0.0,
          'aggressionFactor': 0.0,
          'handsPlayed': 0,
        };
      }

      // Get user stats from database (already updated incrementally from each hand)
      final userStats = await UserStatsService.getUserStats(userId);

      if (userStats == null) {
        return {
          'totalSessions': 0,
          'totalHours': 0.0,
          'winRate': 0.0,
          'currentStreak': 0,
          'avgWeeklyEarnings': 0.0,
          'vpip': 0.0,
          'pfr': 0.0,
          'threeBet': 0.0,
          'aggressionFactor': 0.0,
          'handsPlayed': 0,
        };
      }

      // Calculate win rate from user stats (hands won / hands played)
      final handsPlayed = userStats.handsPlayed;
      final wonHands = userStats.wonHands;
      final winRate = handsPlayed > 0 ? ((wonHands / handsPlayed) * 100).clamp(0.0, 100.0) : 0.0;

      // Calculate total hours from play time minutes
      final totalHours = userStats.totalPlayTimeMinutes / 60.0;

      // Get sessions for weekly earnings calculation
      List<Map<String, dynamic>> sessions = [];
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
      }

      double totalProfit = 0.0;
      for (var session in sessions) {
        if (session.containsKey('profit') && session['profit'] != null) {
          totalProfit += (session['profit'] as num).toDouble();
        } else if (session.containsKey('finalStack') && session.containsKey('totalBuyIn')) {
          double finalStack = (session['finalStack'] as num?)?.toDouble() ?? 0.0;
          double totalBuyIn = (session['totalBuyIn'] as num?)?.toDouble() ?? 0.0;
          totalProfit += (finalStack - totalBuyIn);
        }
      }

      final avgWeeklyEarnings = totalProfit / (sessions.length > 0 ? (sessions.length / 2.0) : 1.0);

      final vpip = userStats.vpipPercentage;
      final pfr = userStats.pfrPercentage;
      final threeBet = userStats.threeBetPercentage;

      final aggressiveActions = userStats.pfrCount.toDouble();
      final passiveActions = (userStats.vpipCount - userStats.pfrCount).toDouble();
      final aggressionFactor = passiveActions > 0
          ? aggressiveActions / passiveActions
          : (aggressiveActions > 0 ? 5.0 : 0.0);

      return {
        'totalSessions': userStats.totalSessions,
        'totalHours': totalHours,
        'winRate': winRate,
        'currentStreak': 0,
        'avgWeeklyEarnings': avgWeeklyEarnings,
        'vpip': vpip,
        'pfr': pfr,
        'threeBet': threeBet,
        'aggressionFactor': aggressionFactor,
        'handsPlayed': userStats.handsPlayed,
        'totalHands': userStats.totalHands,
      };
    } catch (e) {
      debugPrint('Error getting player statistics: $e');
      return {
        'totalSessions': 0,
        'totalHours': 0.0,
        'winRate': 0.0,
        'currentStreak': 0,
        'avgWeeklyEarnings': 0.0,
        'vpip': 0.0,
        'pfr': 0.0,
        'threeBet': 0.0,
        'aggressionFactor': 0.0,
        'handsPlayed': 0,
      };
    }
  }
}
