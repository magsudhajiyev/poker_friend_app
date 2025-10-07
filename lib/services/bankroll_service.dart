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

      // Calculate total hours from actual session durations
      double totalHours = 0.0;
      int wonSessions = 0;
      double totalProfit = 0.0;
      int currentStreak = 0;

      for (var session in sessions) {
        // Calculate hours from session duration if available
        if (session.containsKey('duration') && session['duration'] != null) {
          // Duration is in minutes
          totalHours += (session['duration'] as num).toDouble() / 60.0;
        }

        // Calculate win rate based on profit/loss
        double profit = 0.0;
        if (session.containsKey('profit') && session['profit'] != null) {
          profit = (session['profit'] as num).toDouble();
        } else if (session.containsKey('finalStack') && session.containsKey('totalBuyIn')) {
          // Calculate profit from final stack and buy-in
          double finalStack = (session['finalStack'] as num?)?.toDouble() ?? 0.0;
          double totalBuyIn = (session['totalBuyIn'] as num?)?.toDouble() ?? 0.0;
          profit = finalStack - totalBuyIn;
        }

        totalProfit += profit;
        if (profit > 0) {
          wonSessions++;
        }
      }

      // Calculate win rate as percentage of winning sessions
      double winRate = totalSessions > 0 ? (wonSessions / totalSessions) * 100 : 0.0;

      // Calculate average weekly earnings (rough estimate based on total profit)
      double avgWeeklyEarnings = totalProfit / (totalSessions > 0 ? (totalSessions / 2.0) : 1.0);

      print('📊 DEBUG Stats: Sessions=$totalSessions, Hours=$totalHours, WonSessions=$wonSessions, WinRate=$winRate%, TotalProfit=$totalProfit');

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