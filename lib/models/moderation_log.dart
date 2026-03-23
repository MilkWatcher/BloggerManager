import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationLog {
  final String id;
  final String userId;
  final String moderatorId;
  final String actionType; // ban, warn, delete_post, delete_account
  final String? reason;
  final String? duration; // e.g. '1_day', '3_days', '1_week', '1_month', '1_year'
  final DateTime createdAt;

  ModerationLog({
    required this.id,
    required this.userId,
    required this.moderatorId,
    required this.actionType,
    this.reason,
    this.duration,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'moderatorId': moderatorId,
      'actionType': actionType,
      'reason': reason,
      'duration': duration,
      'createdAt': createdAt,
    };
  }

  factory ModerationLog.fromJson(Map<String, dynamic> json, String id) {
    return ModerationLog(
      id: id,
      userId: json['userId'] as String? ?? '',
      moderatorId: json['moderatorId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      reason: json['reason'] as String?,
      duration: json['duration'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
