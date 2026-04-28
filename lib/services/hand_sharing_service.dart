import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for sharing poker hands via public links.
class HandSharingService {
  HandSharingService._();

  static const String _collection = 'shared_hands';
  static const String _baseUrl = 'https://finaltable.io/hand';
  static final _firestore = FirebaseFirestore.instance;

  /// Share a hand and return the shareable URL.
  static Future<String?> shareHand(
    Map<String, dynamic> hand, {
    bool hideHoleCards = false,
    String? sessionName,
  }) async {
    try {
      final shareId = _generateShareId();
      final doc = _buildSharedDocument(hand, shareId,
          hideHoleCards: hideHoleCards, sessionName: sessionName);
      await _firestore.collection(_collection).doc(shareId).set(doc);
      return '$_baseUrl/$shareId';
    } catch (e) {
      print('Error sharing hand: $e');
      return null;
    }
  }

  static String _generateShareId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Map<String, dynamic> _buildSharedDocument(
    Map<String, dynamic> hand,
    String shareId, {
    bool hideHoleCards = false,
    String? sessionName,
  }) {
    final heroSeat = hand['heroSeatNumber'] as int? ?? 1;
    final winnerId = hand['winnerId'] as int?;
    final isChoppedPot = hand['isChoppedPot'] as bool? ?? false;
    final choppedWinners = hand['choppedWinners'] as List<dynamic>?;

    return {
      'shareId': shareId,
      'handNumber': hand['handNumber'],
      'smallBlind': hand['smallBlind'],
      'bigBlind': hand['bigBlind'],
      'gameType': hand['gameType'],
      'playerCount': hand['playerCount'],
      'heroPositionName': hand['heroPositionName'],
      'heroSeatNumber': heroSeat,
      'buttonPosition': hand['buttonPosition'],
      'potAmount': hand['potAmount'],
      'boardCards': hand['boardCards'],
      'ourHoleCards': hideHoleCards ? null : hand['ourHoleCards'],
      'hideHoleCards': hideHoleCards,
      'sessionName': sessionName,
      'winnerId': winnerId,
      'isChoppedPot': isChoppedPot,
      'choppedWinners': choppedWinners,
      'actions': hand['actions'],
      'playerNames': hand['playerNames'],
      'showdownData': hand['showdownData'],
      'preflopPot': hand['preflopPot'],
      'flopPot': hand['flopPot'],
      'turnPot': hand['turnPot'],
      'riverPot': hand['riverPot'],
      'result': _computeResult(heroSeat, winnerId, isChoppedPot, choppedWinners),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    };
  }

  static String _computeResult(
    int heroSeat,
    int? winnerId,
    bool isChoppedPot,
    List<dynamic>? choppedWinners,
  ) {
    if (isChoppedPot && choppedWinners != null) {
      if (choppedWinners.contains(heroSeat)) return 'Chopped';
      return 'Lost';
    }
    if (winnerId == heroSeat) return 'Won';
    return 'Lost';
  }
}
