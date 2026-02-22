import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blogger_profile.dart';

/// Service for interacting with Firestore database for blogger profiles
class FirestoreService {
  static const String collectionName = 'blogger_profiles';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new blogger profile in Firestore
  Future<String> createBloggerProfile(BloggerProfile profile) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(collectionName)
          .add(profile.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create blogger profile: $e');
    }
  }

  /// Update an existing blogger profile
  Future<void> updateBloggerProfile(String profileId, Map<String, dynamic> data) async {
    try {
      // Always update the updatedAt timestamp
      data['updatedAt'] = DateTime.now();
      await _firestore
          .collection(collectionName)
          .doc(profileId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update blogger profile: $e');
    }
  }

  /// Get a single blogger profile by ID
  Future<BloggerProfile?> getBloggerProfile(String profileId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(collectionName)
          .doc(profileId)
          .get();

      if (doc.exists) {
        return BloggerProfile.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch blogger profile: $e');
    }
  }

  /// Get all blogger profiles (paginated)
  Future<List<BloggerProfile>> getAllBloggerProfiles({
    int limit = 10,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) =>
              BloggerProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch blogger profiles: $e');
    }
  }

  /// Search for blogger profiles by name or category
  Future<List<BloggerProfile>> searchBloggerProfiles(String query) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .get();

      return snapshot.docs
          .map((doc) =>
              BloggerProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search blogger profiles: $e');
    }
  }

  /// Delete a blogger profile
  Future<void> deleteBloggerProfile(String profileId) async {
    try {
      await _firestore.collection(collectionName).doc(profileId).delete();
    } catch (e) {
      throw Exception('Failed to delete blogger profile: $e');
    }
  }

  /// Get profiles by specific category
  Future<List<BloggerProfile>> getProfilesByCategory(String category) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('categories', arrayContains: category)
          .get();

      return snapshot.docs
          .map((doc) =>
              BloggerProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch profiles by category: $e');
    }
  }

  /// Get a stream of all blogger profiles for real-time updates
  Stream<List<BloggerProfile>> getBloggerProfilesStream() {
    try {
      return _firestore
          .collection(collectionName)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BloggerProfile.fromMap(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList());
    } catch (e) {
      throw Exception('Failed to get profiles stream: $e');
    }
  }
}
