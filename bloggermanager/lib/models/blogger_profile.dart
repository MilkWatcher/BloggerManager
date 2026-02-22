/// Represents a blogger's profile in the app
class BloggerProfile {
  final String id; // Firestore document ID
  final String name;
  final String email;
  final String bio;
  final String profileImageUrl;
  final List<String> categories; // Topics/categories they blog about
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final int followerCount;

  BloggerProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.bio,
    required this.profileImageUrl,
    required this.categories,
    required this.createdAt,
    required this.updatedAt,
    required this.isVerified,
    required this.followerCount,
  });

  /// Convert BloggerProfile object to a Map (for storing in Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'categories': categories,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isVerified': isVerified,
      'followerCount': followerCount,
    };
  }

  /// Create a BloggerProfile object from a Firestore document Map
  factory BloggerProfile.fromMap(Map<String, dynamic> map, String docId) {
    return BloggerProfile(
      id: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      bio: map['bio'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      createdAt: (map['createdAt']?.toDate() ?? DateTime.now()),
      updatedAt: (map['updatedAt']?.toDate() ?? DateTime.now()),
      isVerified: map['isVerified'] ?? false,
      followerCount: map['followerCount'] ?? 0,
    );
  }

  /// Create a copy of BloggerProfile with optional field updates
  BloggerProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? bio,
    String? profileImageUrl,
    List<String>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    int? followerCount,
  }) {
    return BloggerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      followerCount: followerCount ?? this.followerCount,
    );
  }
}
