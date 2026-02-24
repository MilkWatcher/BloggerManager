import 'package:cloud_firestore/cloud_firestore.dart';

class BloggerUser {
  final String userId;
  final String email;
  final String displayName;
  final GeoPoint? location;
  final String? areaCode;
  final String? domainLink;
  final String? profileDetails;
  final List<String> tags;
  final String verificationStatus; // Pending, Approved, Denied
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  BloggerUser({
    required this.userId,
    required this.email,
    required this.displayName,
    this.location,
    this.areaCode,
    this.domainLink,
    this.profileDetails,
    this.tags = const [],
    this.verificationStatus = 'Pending',
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  // Convert BloggerUser to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': userId,
      'email': email,
      'displayName': displayName,
      'location': location,
      'areaCode': areaCode,
      'domainLink': domainLink,
      'profileDetails': profileDetails,
      'tags': tags,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastLoginAt': lastLoginAt,
    };
  }

  // Create BloggerUser from Firestore document
  factory BloggerUser.fromJson(Map<String, dynamic> json, String userId) {
    return BloggerUser(
      userId: userId,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      location: json['location'] as GeoPoint?,
      areaCode: json['areaCode'] as String?,
      domainLink: json['domainLink'] as String?,
      profileDetails: json['profileDetails'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? []),
      verificationStatus: json['verificationStatus'] as String? ?? 'Pending',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  // Create a copy with modifications
  BloggerUser copyWith({
    String? userId,
    String? email,
    String? displayName,
    GeoPoint? location,
    String? areaCode,
    String? domainLink,
    String? profileDetails,
    List<String>? tags,
    String? verificationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return BloggerUser(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      location: location ?? this.location,
      areaCode: areaCode ?? this.areaCode,
      domainLink: domainLink ?? this.domainLink,
      profileDetails: profileDetails ?? this.profileDetails,
      tags: tags ?? this.tags,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
