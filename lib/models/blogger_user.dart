import 'package:cloud_firestore/cloud_firestore.dart';

class BloggerUser {
  final String userId;
  final String email;
  final String displayName;
  final String? domainLink;
  final String? profileImageBase64;
  final GeoPoint? location;
  final String? city;
  final String? county;
  final String? country;
  final String? cityCounty;
  final String? areaCode;
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
    this.domainLink,
    this.profileImageBase64,
    this.location,
    this.city,
    this.county,
    this.country,
    this.cityCounty,
    this.areaCode,
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
      'domainLink': domainLink,
      'profileImageBase64': profileImageBase64,
      'location': location,
      'city': city,
      'county': county,
      'country': country,
      'cityCounty': cityCounty,
      'areaCode': areaCode,
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
      domainLink: json['domainLink'] as String?,
      profileImageBase64: json['profileImageBase64'] as String?,
      location: json['location'] as GeoPoint?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      country: json['country'] as String?,
      cityCounty: json['cityCounty'] as String?,
      areaCode: json['areaCode'] as String?,
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
    String? domainLink,
    String? profileImageBase64,
    GeoPoint? location,
    String? city,
    String? county,
    String? country,
    String? cityCounty,
    String? areaCode,
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
      domainLink: domainLink ?? this.domainLink,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      location: location ?? this.location,
      city: city ?? this.city,
      county: county ?? this.county,
      country: country ?? this.country,
      cityCounty: cityCounty ?? this.cityCounty,
      areaCode: areaCode ?? this.areaCode,
      profileDetails: profileDetails ?? this.profileDetails,
      tags: tags ?? this.tags,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
