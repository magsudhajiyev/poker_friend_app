import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents an opponent player with their stats and playing style
class Opponent {
  final String id;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  // Color coding for quick identification
  final OpponentColor color;

  // NOTE: Statistical data (handsPlayed, vpip, pfr, etc.) is stored in OpponentStats
  // for performance optimization. See OpponentStatsService for stat queries.

  Opponent({
    required this.id,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.lastSeenAt,
    this.color = OpponentColor.blue,
  });

  /// Factory constructor from Firestore document
  factory Opponent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Opponent(
      id: doc.id,
      name: data['name'] ?? '',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      color: OpponentColor.values.firstWhere(
        (e) => e.name == data['color'],
        orElse: () => OpponentColor.blue
      ),
    );
  }

  /// Factory constructor from local storage map
  factory Opponent.fromMap(Map<String, dynamic> map) {
    return Opponent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      notes: map['notes'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      lastSeenAt: DateTime.tryParse(map['lastSeenAt'] ?? '') ?? DateTime.now(),
      color: OpponentColor.values.firstWhere(
        (e) => e.name == map['color'],
        orElse: () => OpponentColor.blue
      ),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'color': color.name,
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'color': color.name,
    };
  }

  /// Create a copy with updated values
  /// Use clearNotes: true to explicitly set notes to null
  Opponent copyWith({
    String? id,
    String? name,
    String? notes,
    bool clearNotes = false,
    DateTime? lastSeenAt,
    OpponentColor? color,
  }) {
    return Opponent(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      color: color ?? this.color,
    );
  }

}

/// Player type classification
enum PlayerType {
  tightAggressive,
  tightPassive,
  looseAggressive,
  loosePassive,
  tagRegular,
  maniac,
  calling_station,
  unknown,
}

/// Color coding for opponents
enum OpponentColor {
  red,
  blue,
  green,
  orange,
  purple,
  teal,
  pink,
  indigo,
}

extension OpponentColorExtension on OpponentColor {
  String get displayName {
    switch (this) {
      case OpponentColor.red:
        return 'Red';
      case OpponentColor.blue:
        return 'Blue';
      case OpponentColor.green:
        return 'Green';
      case OpponentColor.orange:
        return 'Orange';
      case OpponentColor.purple:
        return 'Purple';
      case OpponentColor.teal:
        return 'Teal';
      case OpponentColor.pink:
        return 'Pink';
      case OpponentColor.indigo:
        return 'Indigo';
    }
  }

  Color get flutterColor {
    switch (this) {
      case OpponentColor.red:
        return Colors.red;
      case OpponentColor.blue:
        return Colors.blue;
      case OpponentColor.green:
        return Colors.green;
      case OpponentColor.orange:
        return Colors.orange;
      case OpponentColor.purple:
        return Colors.purple;
      case OpponentColor.teal:
        return Colors.teal;
      case OpponentColor.pink:
        return Colors.pink;
      case OpponentColor.indigo:
        return Colors.indigo;
    }
  }
}