import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/blogger_profile.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'bloggers';

  /// Get blogger profile by user ID
  Future<BloggerProfile?> getBloggerProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(collectionName)
          .doc(userId)
          .get();

      if (doc.exists) {
        return BloggerProfile.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Update blogger profile
  Future<void> updateBloggerProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('Firestore: Starting profile update for user: $userId');
      debugPrint('Firestore: Updates: $updates');
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      // Use set with merge - creates if doesn't exist
      await _firestore
          .collection(collectionName)
          .doc(userId)
          .set(updates, SetOptions(merge: true));
      
      debugPrint('Firestore: Profile update successful!');
    } catch (e) {
      debugPrint('Firestore ERROR: $e');
      throw Exception('Failed to save profile: $e');
    }
  }

  /// Get all bloggers
  Future<List<BloggerProfile>> getApprovedBloggers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerProfile.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bloggers: $e');
    }
  }

  /// Search bloggers by tags
  Future<List<BloggerProfile>> searchBloggersByTag(String tag) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('tags', arrayContains: tag)
          .get();

      return snapshot.docs
          .map((doc) => BloggerProfile.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      throw Exception('Failed to search bloggers: $e');
    }
  }

  /// Get all bloggers (admin view)
  Future<List<BloggerProfile>> getAllBloggers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerProfile.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch all bloggers: $e');
    }
  }

  /// Get pending bloggers (for admin approval)
  Future<List<BloggerProfile>> getPendingBloggers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('verification_status', isEqualTo: 'Pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerProfile.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending bloggers: $e');
    }
  }

  /// Create initial profile after signup
  Future<void> createInitialProfile(String userId, String email, String displayName) async {
    try {
      debugPrint('Firestore: Creating initial profile for user: $userId');
      debugPrint('Firestore: Writing to collection: $collectionName, doc: $userId');
      
      // Add a small delay to ensure auth token is available
      await Future.delayed(const Duration(milliseconds: 500));
      
      final profileData = {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'profile_details': '',
        'domain_link': '',
        'tags': [],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'verification_status': 'Pending',
      };
      
      debugPrint('Firestore: Profile data prepared, about to write...');
      
      int retries = 0;
      const maxRetries = 3;
      
      while (retries < maxRetries) {
        try {
          await _firestore.collection(collectionName).doc(userId).set(profileData).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Firestore write timeout after 10 seconds');
            },
          );
          debugPrint('Firestore: Initial profile created successfully!');
          return;
        } catch (e) {
          retries++;
          debugPrint('Firestore: Write attempt $retries failed: $e');
          if (retries < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      
      throw Exception('Failed to create profile after $maxRetries retries');
    } catch (e) {
      debugPrint('Firestore: Failed to create initial profile: $e');
      debugPrint('Firestore: Error type: ${e.runtimeType}');
      throw Exception('Failed to create profile: $e');
    }
  }

  /// Update verification status (admin only)
  Future<void> updateVerificationStatus(
    String userId,
    String status, // "Approved" or "Denied"
  ) async {
    try {
      await _firestore.collection(collectionName).doc(userId).update({
        'verification_status': status,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update verification status: $e');
    }
  }

  /// Stream of user's own profile (real-time updates)
  Stream<BloggerProfile?> getUserProfileStream(String userId) {
    return _firestore
        .collection(collectionName)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return BloggerProfile.fromMap(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id,
        );
      }
      return null;
    });
  }
}
