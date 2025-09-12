import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';

class BankrollService {
  static const String _goalKey = 'bankroll_goal';
  static const String _currentBankrollKey = 'current_bankroll';

  // Get bankroll goal
  static Future<double> getBankrollGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_goalKey) ?? 20000.0; // Default goal
    } catch (e) {
      print('Error getting bankroll goal: $e');
      return 20000.0;
    }
  }

  // Set bankroll goal
  static Future<void> setBankrollGoal(double goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_goalKey, goal);
    } catch (e) {
      print('Error setting bankroll goal: $e');
    }
  }

  // Get current bankroll
  static Future<double> getCurrentBankroll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_currentBankrollKey) ?? 7200.0; // Default current
    } catch (e) {
      print('Error getting current bankroll: $e');
      return 7200.0;
    }
  }

  // Set current bankroll
  static Future<void> setCurrentBankroll(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_currentBankrollKey, amount);
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

  // Get statistics from sessions
  static Future<Map<String, dynamic>> getPlayerStatistics() async {
    try {
      // Get all sessions
      List<Map<String, dynamic>> sessions = [];
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
      }

      if (sessions.isEmpty) {
        return {
          'totalSessions': 0,
          'totalHours': 0.0,
          'winRate': 0.0,
          'currentStreak': 0,
          'avgWeeklyEarnings': 0.0,
        };
      }

      // Calculate total sessions
      int totalSessions = sessions.length;

      // Calculate total hours (estimate based on session count)
      double totalHours = totalSessions * 1.5; // Estimate 1.5 hours per session

      // Calculate win rate (simplified - based on positive profit sessions)
      int wonSessions = 0;
      double totalProfit = 0.0;
      
      // Placeholder data - replace with real calculations later
      double winRate = 74.0; // 74% win rate for demonstration
      int currentStreak = 0;
      double avgWeeklyEarnings = 0.0;

      return {
        'totalSessions': totalSessions,
        'totalHours': totalHours,
        'winRate': winRate,
        'currentStreak': currentStreak,
        'avgWeeklyEarnings': avgWeeklyEarnings,
      };
    } catch (e) {
      print('Error getting player statistics: $e');
      return {
        'totalSessions': 0,
        'totalHours': 0.0,
        'winRate': 0.0,
        'currentStreak': 0,
        'avgWeeklyEarnings': 0.0,
      };
    }
  }
}