import 'package:cloud_firestore/cloud_firestore.dart';

/// Role within a club
enum ClubRole {
  owner,    // Full control, can do everything
  admin,    // Can manage dealers and tables
  dealer,   // Can deal at tables
  player,   // Can play (reserved for future use)
}

extension ClubRoleExtension on ClubRole {
  String get displayName {
    switch (this) {
      case ClubRole.owner:
        return 'Owner';
      case ClubRole.admin:
        return 'Admin';
      case ClubRole.dealer:
        return 'Dealer';
      case ClubRole.player:
        return 'Player';
    }
  }

  String get value {
    switch (this) {
      case ClubRole.owner:
        return 'owner';
      case ClubRole.admin:
        return 'admin';
      case ClubRole.dealer:
        return 'dealer';
      case ClubRole.player:
        return 'player';
    }
  }

  static ClubRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'owner':
        return ClubRole.owner;
      case 'admin':
        return ClubRole.admin;
      case 'dealer':
        return ClubRole.dealer;
      case 'player':
      default:
        return ClubRole.player;
    }
  }

  /// Check if this role can manage dealers
  bool get canManageDealers =>
      this == ClubRole.owner || this == ClubRole.admin;

  /// Check if this role can manage tables
  bool get canManageTables =>
      this == ClubRole.owner || this == ClubRole.admin;

  /// Check if this role can deal at tables
  bool get canDeal =>
      this == ClubRole.owner || this == ClubRole.admin || this == ClubRole.dealer;
}

/// Represents a member of a club
class ClubMember {
  final String id;
  final String userId;
  final String? displayName;
  final String? email;
  final ClubRole role;
  final DateTime joinedAt;

  ClubMember({
    required this.id,
    required this.userId,
    this.displayName,
    this.email,
    required this.role,
    required this.joinedAt,
  });

  /// Factory constructor from Firestore document
  factory ClubMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubMember(
      id: doc.id,
      userId: data['userId'] ?? '',
      displayName: data['displayName'],
      email: data['email'],
      role: ClubRoleExtension.fromString(data['role']),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Factory constructor from map
  factory ClubMember.fromMap(Map<String, dynamic> map) {
    return ClubMember(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      displayName: map['displayName'],
      email: map['email'],
      role: ClubRoleExtension.fromString(map['role']),
      joinedAt: DateTime.tryParse(map['joinedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'role': role.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'role': role.value,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  ClubMember copyWith({
    String? displayName,
    String? email,
    ClubRole? role,
  }) {
    return ClubMember(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedAt: joinedAt,
    );
  }
}
