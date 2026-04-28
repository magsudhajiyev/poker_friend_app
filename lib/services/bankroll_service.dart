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

  // Get bankroll goal
  static Future<double> getBankrollGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_goalKey) ?? 0.0;
    } catch (e) {
      print('Error getting bankroll goal: $e');
      return 0.0;
    }
  }

  // Set bankroll goal
  static Future<void> setBankrollGoal(double goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_goalKey, goal);
      AppDataCache.markHomeDirty();
    } catch (e) {
      print('Error setting bankroll goal: $e');
    }
  }

  // Get current bankroll
  static Future<double> getCurrentBankroll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_currentBankrollKey) ?? 0.0;
    } catch (e) {
      print('Error getting current bankroll: $e');
      return 0.0;
    }
  }

  // Set current bankroll
  static Future<void> setCurrentBankroll(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_currentBankrollKey, amount);
      AppDataCache.markHomeDirty();
    } catch (e) {
      print('Error setting current bankroll: $e');
    }
  }

  // Add to bankroll (for session results)
  static Future<void> addToBankroll(double amount) async {
    try {
      final current = await getCurrentBankroll();
      await setCurrentBankroll(current + amount);
    } catch (e) {
      print('Error adding to bankroll: $e');
    }
  }

  // Get bankroll progress (0.0 to 1.0)
  static Future<double> getBankrollProgress() async {
    try {
      final current = await getCurrentBankroll();
      final goal = await getBankrollGoal();
      final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
      print('💰 DEBUG: Current: $current, Goal: $goal, Progress: $progress');
      return progress;
    } catch (e) {
      print('Error calculating bankroll progress: $e');
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
      print('Error calculating remaining to goal: $e');
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
      // Win rate should only count hands where we voluntarily put money in
      final handsPlayed = userStats.handsPlayed;
      final wonHands = userStats.wonHands;
      final winRate = handsPlayed > 0 ? (wonHands / handsPlayed) * 100 : 0.0;

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

      // Calculate VPIP, PFR, 3-bet percentages for play style detection
      // IMPORTANT: Denominator must be totalHands (all hands dealt), NOT handsPlayed
      // VPIP = "Voluntarily Put money In Pot" - percentage of ALL dealt hands where player VPIP'd
      // Using handsPlayed would give inflated values (e.g., 100% if player only records VPIP hands)
      final vpip = userStats.totalHands > 0
          ? (userStats.vpipCount / userStats.totalHands) * 100
          : 0.0;
      final pfr = userStats.totalHands > 0
          ? (userStats.pfrCount / userStats.totalHands) * 100
          : 0.0;
      final threeBet = userStats.totalHands > 0
          ? (userStats.threeBetCount / userStats.totalHands) * 100
          : 0.0;

      // Calculate aggression factor
      // AF = aggressive actions (bet/raise) / passive actions (call)
      // Approximate: PFR count represents aggressive actions, (VPIP - PFR) represents calls
      final aggressiveActions = userStats.pfrCount.toDouble();
      final passiveActions = (userStats.vpipCount - userStats.pfrCount).toDouble();
      final aggressionFactor = passiveActions > 0
          ? aggressiveActions / passiveActions
          : (aggressiveActions > 0 ? 5.0 : 0.0); // If only aggressive, set high AF

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
      };
    } catch (e) {
      print('Error getting player statistics: $e');
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