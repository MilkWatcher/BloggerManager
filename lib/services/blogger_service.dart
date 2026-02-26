import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/blogger_user.dart';

class BloggerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  // Get a blogger by ID
  Future<BloggerUser?> getBlogger(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return BloggerUser.fromJson(doc.data()!, userId);
      }
      return null;
    } catch (e) {
      developer.log('Error getting blogger: $e', error: e, name: 'BloggerService');
      return null;
    }
  }

  // Update blogger profile
  Future<void> updateBloggerProfile(
    String userId,
    String displayName,
    String domainLink,
    String? profileDetails,
    GeoPoint? location,
    String? city,
    String? county,
    String? country,
    List<String> tags,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'displayName': displayName,
        'domainLink': domainLink,
        'profileDetails': profileDetails,
        'location': location,
        'city': city,
        'county': county,
        'country': country,
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error updating blogger profile: $e', error: e, name: 'BloggerService');
      rethrow;
    }
  }

  // Get all approved bloggers
  Future<List<BloggerUser>> getApprovedBloggers() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_usersCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerUser.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error getting approved bloggers: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  // Search bloggers by tags
  Future<List<BloggerUser>> searchByTags(List<String> tags) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_usersCollection)
          .where('tags', arrayContainsAny: tags)
          .get();

      return snapshot.docs
          .map((doc) => BloggerUser.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error searching by tags: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  // Search bloggers by location (radius search - basic)
  Future<List<BloggerUser>> searchByLocation(GeoPoint center, double radiusKm) async {
    try {
      // Basic approach: get all bloggers and filter client-side
      // For production, consider using a geohashing library or Google Cloud Firestore extension
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_usersCollection)
          .where('location', isNotEqualTo: null)
          .get();

      final List<BloggerUser> allBloggers = snapshot.docs
          .map((doc) => BloggerUser.fromJson(doc.data(), doc.id))
          .toList();

      // Filter by distance (Haversine formula)
      return allBloggers.where((blogger) {
        if (blogger.location == null) return false;
        final double distance = _calculateDistance(
          center.latitude,
          center.longitude,
          blogger.location!.latitude,
          blogger.location!.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      developer.log('Error searching by location: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double sinDLat = sin(dLat / 2);
    final double sinDLon = sin(dLon / 2);
    final double a = sinDLat * sinDLat +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sinDLon *
            sinDLon;

    final double c = 2 * asin(sqrt(a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Get pending blogger approvals (for moderators)
  Future<List<BloggerUser>> getPendingBloggers() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_usersCollection)
          .where('verificationStatus', isEqualTo: 'Pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerUser.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error getting pending bloggers: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  // Approve a blogger
  Future<void> approveBlogger(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'verificationStatus': 'Approved',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error approving blogger: $e', error: e, name: 'BloggerService');
      rethrow;
    }
  }

  // Deny a blogger
  Future<void> denyBlogger(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'verificationStatus': 'Denied',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('Error denying blogger: $e', error: e, name: 'BloggerService');
      rethrow;
    }
  }
}
