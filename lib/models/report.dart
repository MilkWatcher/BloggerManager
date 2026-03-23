import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String reporterId;
  final String reporterEmail;
  final String targetType; // 'blog' or 'blogger'
  final String targetId;
  final String targetName;
  final String reason; // Spam, Plagiarism, Harmful Content, Inaccurate Info, Inappropriate, Other
  final String? details;
  final String status; // pending, reviewed, resolved, dismissed
  final String? moderatorId;
  final String? moderatorNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reporterEmail,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.reason,
    this.details,
    this.status = 'pending',
    this.moderatorId,
    this.moderatorNotes,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'reason': reason,
      'details': details,
      'status': status,
      'moderatorId': moderatorId,
      'moderatorNotes': moderatorNotes,
      'createdAt': createdAt,
      'resolvedAt': resolvedAt,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json, String id) {
    return Report(
      id: id,
      reporterId: json['reporterId'] as String? ?? '',
      reporterEmail: json['reporterEmail'] as String? ?? '',
      targetType: json['targetType'] as String? ?? 'blog',
      targetId: json['targetId'] as String? ?? '',
      targetName: json['targetName'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String?,
      status: json['status'] as String? ?? 'pending',
      moderatorId: json['moderatorId'] as String?,
      moderatorNotes: json['moderatorNotes'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}
