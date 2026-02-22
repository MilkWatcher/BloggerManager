import 'package:cloud_firestore/cloud_firestore.dart';

class BloggerProfile {
  final String userId; // User ID from Firebase Auth
  final GeoPoint location; // Latitude and longitude
  final String domainLink; // Blog/portfolio link
  final String profileDetails; // Bio and social handles
  final List<String> tags; // Categories e.g. ["Politics", "Food"]
  final String verificationStatus; // "Pending", "Approved", "Denied"
  final DateTime createdAt;
  final DateTime updatedAt;
  final String displayName;
  final String email;

  BloggerProfile({
    required this.userId,
    required this.location,
    required this.domainLink,
    required this.profileDetails,
    required this.tags,
    required this.verificationStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.displayName,
    required this.email,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'location': location,
      'domain_link': domainLink,
      'profile_details': profileDetails,
      'tags': tags,
      'verification_status': verificationStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'displayName': displayName,
      'email': email,
    };
  }

  /// Create from Firestore document
  factory BloggerProfile.fromMap(Map<String, dynamic> map, String docId) {
    return BloggerProfile(
      userId: docId,
      location: map['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      domainLink: map['domain_link'] as String? ?? '',
      profileDetails: map['profile_details'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? []),
      verificationStatus: map['verification_status'] as String? ?? 'Pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }

  /// Copy with updates
  BloggerProfile copyWith({
    String? userId,
    GeoPoint? location,
    String? domainLink,
    String? profileDetails,
    List<String>? tags,
    String? verificationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? displayName,
    String? email,
  }) {
    return BloggerProfile(
      userId: userId ?? this.userId,
      location: location ?? this.location,
      domainLink: domainLink ?? this.domainLink,
      profileDetails: profileDetails ?? this.profileDetails,
      tags: tags ?? this.tags,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
    );
  }
}
