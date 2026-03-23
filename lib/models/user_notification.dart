import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotification {
  final String id;
  final String userId;
  final String type; // ban, warn
  final String? message;
  final String? reason;
  final DateTime? banExpiry;
  final bool acknowledged;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.message,
    this.reason,
    this.banExpiry,
    this.acknowledged = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type,
      'message': message,
      'reason': reason,
      'banExpiry': banExpiry,
      'acknowledged': acknowledged,
      'createdAt': createdAt,
    };
  }

  factory UserNotification.fromJson(Map<String, dynamic> json, String id) {
    return UserNotification(
      id: id,
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      message: json['message'] as String?,
      reason: json['reason'] as String?,
      banExpiry: (json['banExpiry'] as Timestamp?)?.toDate(),
      acknowledged: json['acknowledged'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
