import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'analytics_service.dart';

class SessionResultService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _sessionResultsCollection = 'session_results';

  // Add a session result
  static Future<void> addSessionResult({
    required double amount,
    required String gameType, // 'cash' or 'tournament'
    double? buyInAmount,
    double? prizeWon,
    int? finishedPlace,
    int? fieldSize,
    int? durationMinutes,
    Map<String, Object>? coverage, // SessionCoverage.compute(...), easy logging
  }) async {
    try {
      final userId = AuthService.currentUser?.uid;
      final userEmail = AuthService.currentUser?.email;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final data = <String, dynamic>{
        'userId': userId,
        'userEmail': userEmail,
        'amount': amount,
        'gameType': gameType,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (buyInAmount != null) data['buyInAmount'] = buyInAmount;
      if (prizeWon != null) data['prizeWon'] = prizeWon;
      if (finishedPlace != null) data['finishedPlace'] = finishedPlace;
      if (fieldSize != null) data['fieldSize'] = fieldSize;
      if (durationMinutes != null) data['durationMinutes'] = durationMinutes;

      await _firestore.collection(_sessionResultsCollection).add(data);

      AnalyticsService.capture('session_ended', {
        'game_type': gameType,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (coverage != null) ...coverage,
      });

      debugPrint('✅ Session result added: $amount ($gameType)');
    } catch (e) {
      debugPrint('Error adding session result: $e');
      rethrow;
    }
  }

  // Get all session results for current user
  static Future<List<Map<String, dynamic>>> getAllSessionResults() async {
    try {
      final userId = AuthService.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
          .collection(_sessionResultsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting session results: $e');
      return [];
    }
  }

  // Get session results for a specific date range
  static Future<List<Map<String, dynamic>>> getSessionResultsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final userId = AuthService.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
          .collection(_sessionResultsCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting session results by date range: $e');
      return [];
    }
  }

  // Get aggregated data for earnings chart (grouped by week or day)
  static Future<Map<String, dynamic>> getEarningsChartData({
    int daysBack = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      final results = await getSessionResultsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      // Group by date and game type
      Map<String, Map<String, double>> groupedData = {};

      for (var result in results) {
        DateTime date;
        if (result['timestamp'] != null) {
          date = (result['timestamp'] as Timestamp).toDate();
        } else if (result['createdAt'] != null) {
          date = DateTime.parse(result['createdAt']);
        } else {
          continue;
        }

        final dateKey = '${date.month}/${date.day}';
        final gameType = result['gameType'] as String? ?? 'cash';
        final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;

        if (!groupedData.containsKey(dateKey)) {
          groupedData[dateKey] = {'tournament': 0.0, 'cash': 0.0};
        }

        groupedData[dateKey]![gameType] = (groupedData[dateKey]![gameType] ?? 0.0) + amount;
      }

      return {
        'chartData': groupedData,
        'totalCash': results
            .where((r) => r['gameType'] == 'cash')
            .fold<double>(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0)),
        'totalTournament': results
            .where((r) => r['gameType'] == 'tournament')
            .fold<double>(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0)),
      };
    } catch (e) {
      debugPrint('Error getting earnings chart data: $e');
      return {'chartData': {}, 'totalCash': 0.0, 'totalTournament': 0.0};
    }
  }
}
