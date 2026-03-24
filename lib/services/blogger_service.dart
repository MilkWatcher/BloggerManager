import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/blogger_user.dart';
import '../models/moderation_log.dart';
import '../models/report.dart';
import 'email_service.dart';

class BloggerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  static const String _usersCollection = 'users';
  static const String _blogsCollection = 'blogs';
  static const String _moderationLogsCollection = 'moderation_logs';
  static const String _reportsCollection = 'reports';
  final EmailService _emailService = EmailService();

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
    String? domainLink,
    String? profileDetails,
    String? profileImageBase64,
    String? xUrl,
    String? instagramUrl,
    String? facebookUrl,
    GeoPoint? location,
    String? city,
    String? county,
    String? country,
    String? cityCounty,
    List<String> tags,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'displayName': displayName,
        'domainLink': domainLink,
        'profileDetails': profileDetails,
        'profileImageBase64': profileImageBase64,
        'xUrl': xUrl,
        'instagramUrl': instagramUrl,
        'facebookUrl': facebookUrl,
        'location': location,
        'city': city,
        'county': county,
        'country': country,
        'cityCounty': cityCounty,
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

  // ─── MODERATION METHODS ─────────────────────────────────────────

  /// Validate that the target user is a blogger (not admin or moderator)
  Future<void> _validateModerationTarget(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    if (!doc.exists) throw Exception('User not found.');
    final role = doc.data()?['role'] as String? ?? 'blogger';
    if (role == 'admin' || role == 'moderator') {
      throw Exception('Cannot perform moderation actions on admins or moderators.');
    }
  }

  /// Ban a blogger for a specified duration
  Future<void> banBlogger({
    required String userId,
    required String moderatorId,
    required String duration,
    String? reason,
  }) async {
    await _validateModerationTarget(userId);

    final DateTime banExpiry = _calculateBanExpiry(duration);
    final blogger = await getBlogger(userId);

    // Update user status
    await _firestore.collection(_usersCollection).doc(userId).set({
      'status': 'banned',
      'banExpiry': Timestamp.fromDate(banExpiry),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Create moderation log
    await _firestore.collection(_moderationLogsCollection).add({
      'userId': userId,
      'moderatorId': moderatorId,
      'actionType': 'ban',
      'reason': reason,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the user
    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection('notifications')
        .add({
      'userId': userId,
      'type': 'ban',
      'message': 'Your account has been banned for ${_formatDuration(duration)}.',
      'reason': reason,
      'banExpiry': Timestamp.fromDate(banExpiry),
      'acknowledged': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send email notification
    if (blogger != null) {
      await _emailService.sendBanNotification(
        toEmail: blogger.email,
        toName: blogger.displayName,
        reason: reason,
        duration: duration,
        expiryDate: banExpiry,
      );
    }
  }

  /// Warn a blogger
  Future<void> warnBlogger({
    required String userId,
    required String moderatorId,
    String? reason,
  }) async {
    await _validateModerationTarget(userId);

    final blogger = await getBlogger(userId);

    // Create moderation log
    await _firestore.collection(_moderationLogsCollection).add({
      'userId': userId,
      'moderatorId': moderatorId,
      'actionType': 'warn',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the user
    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection('notifications')
        .add({
      'userId': userId,
      'type': 'warn',
      'message': 'You have received a warning from a moderator.',
      'reason': reason,
      'acknowledged': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send email notification
    if (blogger != null) {
      await _emailService.sendWarningNotification(
        toEmail: blogger.email,
        toName: blogger.displayName,
        reason: reason,
      );
    }
  }

  /// Delete a blog post (moderator action)
  Future<void> deleteBlog({
    required String blogId,
    required String moderatorId,
    String? reason,
  }) async {
    final blogDoc = await _firestore.collection(_blogsCollection).doc(blogId).get();
    final String? uploadedBy = blogDoc.data()?['uploadedBy'] as String?;

    await _firestore.collection(_blogsCollection).doc(blogId).delete();

    // Create moderation log
    await _firestore.collection(_moderationLogsCollection).add({
      'userId': uploadedBy ?? 'unknown',
      'moderatorId': moderatorId,
      'actionType': 'delete_post',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a blogger account and all their blogs (moderator action)
  Future<void> deleteBloggerAccount({
    required String userId,
    required String moderatorId,
    String? reason,
  }) async {
    await _validateModerationTarget(userId);

    // Delete all blogs by this user
    final blogsSnapshot = await _firestore
        .collection(_blogsCollection)
        .where('uploadedBy', isEqualTo: userId)
        .get();
    for (final doc in blogsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete all notifications for this user
    final notifSnapshot = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection('notifications')
        .get();
    for (final doc in notifSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the user document
    await _firestore.collection(_usersCollection).doc(userId).delete();

    // Create moderation log
    await _firestore.collection(_moderationLogsCollection).add({
      'userId': userId,
      'moderatorId': moderatorId,
      'actionType': 'delete_account',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Assign moderator role to a blogger (admin-only)
  Future<void> assignModeratorRole(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    if (!doc.exists) throw Exception('User not found.');
    final role = doc.data()?['role'] as String? ?? 'blogger';
    if (role == 'admin') throw Exception('Cannot modify admin role.');

    await _firestore.collection(_usersCollection).doc(userId).set({
      'role': 'moderator',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove moderator role from a user (admin-only)
  Future<void> removeModeratorRole(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    if (!doc.exists) throw Exception('User not found.');
    final role = doc.data()?['role'] as String? ?? 'blogger';
    if (role == 'admin') throw Exception('Cannot modify admin role.');

    await _firestore.collection(_usersCollection).doc(userId).set({
      'role': 'blogger',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get all moderation logs, optionally filtered by userId
  Future<List<ModerationLog>> getModerationLogs({String? userId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_moderationLogsCollection)
          .orderBy('createdAt', descending: true);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ModerationLog.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error getting moderation logs: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  /// Get all bloggers (for moderator user list) — excludes admins
  Future<List<BloggerUser>> getAllBloggers() async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerUser.fromJson(doc.data(), doc.id))
          .where((user) => user.role != 'admin')
          .toList();
    } catch (e) {
      developer.log('Error getting all bloggers: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  /// Get all blog posts (for content moderation)
  Future<List<Map<String, dynamic>>> getAllBlogs() async {
    try {
      final snapshot = await _firestore
          .collection(_blogsCollection)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      developer.log('Error getting all blogs: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  /// Get all users (for role management) — admin can see all
  Future<List<BloggerUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloggerUser.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error getting all users: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  /// Get warning count for a user
  Future<int> getWarningCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_moderationLogsCollection)
          .where('userId', isEqualTo: userId)
          .where('actionType', isEqualTo: 'warn')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  DateTime _calculateBanExpiry(String duration) {
    final now = DateTime.now();
    switch (duration) {
      case '1_day':
        return now.add(const Duration(days: 1));
      case '3_days':
        return now.add(const Duration(days: 3));
      case '1_week':
        return now.add(const Duration(days: 7));
      case '1_month':
        return now.add(const Duration(days: 30));
      case '1_year':
        return now.add(const Duration(days: 365));
      default:
        return now.add(const Duration(days: 1));
    }
  }

  String _formatDuration(String duration) {
    switch (duration) {
      case '1_day':
        return '1 day';
      case '3_days':
        return '3 days';
      case '1_week':
        return '1 week';
      case '1_month':
        return '1 month';
      case '1_year':
        return '1 year';
      default:
        return duration;
    }
  }

  // ─── REPORT METHODS ──────────────────────────────────────────

  /// Submit a report against a blog or blogger
  Future<void> submitReport({
    required String reporterId,
    required String reporterEmail,
    required String targetType,
    required String targetId,
    required String targetName,
    required String reason,
    String? details,
  }) async {
    await _firestore.collection(_reportsCollection).add({
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if a user already reported a specific target
  Future<bool> hasUserReported(String reporterId, String targetId) async {
    try {
      final snapshot = await _firestore
          .collection(_reportsCollection)
          .where('reporterId', isEqualTo: reporterId)
          .where('targetId', isEqualTo: targetId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get all reports, optionally filtered by status
  Future<List<Report>> getAllReports({String? status}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_reportsCollection)
          .orderBy('createdAt', descending: true);

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Report.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error getting reports: $e', error: e, name: 'BloggerService');
      return [];
    }
  }

  /// Resolve, review, or dismiss a report
  Future<void> updateReportStatus({
    required String reportId,
    required String moderatorId,
    required String status,
    String? moderatorNotes,
    String? targetName,
  }) async {
    await _firestore.collection(_reportsCollection).doc(reportId).update({
      'status': status,
      'moderatorId': moderatorId,
      'moderatorNotes': moderatorNotes,
      if (status == 'resolved' || status == 'dismissed')
        'resolvedAt': FieldValue.serverTimestamp(),
    });

    // Log report action in moderation logs
    await _firestore.collection(_moderationLogsCollection).add({
      'userId': targetName ?? reportId,
      'moderatorId': moderatorId,
      'actionType': 'report_$status',
      'reason': moderatorNotes ?? 'Report $status',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── BLOG FETCH BY ID ────────────────────────────────────────

  /// Look up a single user's displayName (returns uid if not found).
  Future<String> getUserDisplayName(String userId) async {
    if (userId == 'AUTOMOD') return 'Automod';
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['displayName'] as String?) ?? userId;
      }
    } catch (_) {}
    return userId;
  }

  /// Get a single blog by its document ID.
  Future<Map<String, dynamic>?> getBlogById(String blogId) async {
    try {
      final doc = await _firestore.collection(_blogsCollection).doc(blogId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      developer.log('Error getting blog by ID: $e', error: e, name: 'BloggerService');
      return null;
    }
  }

  // ─── AUTOMOD LOGGING ─────────────────────────────────────────

  /// Log an automod action (blocked upload due to blacklisted words).
  Future<void> logAutomodAction({
    required String userId,
    required String blogTitle,
    required List<String> matchedWords,
  }) async {
    await _firestore.collection(_moderationLogsCollection).add({
      'userId': userId,
      'moderatorId': 'AUTOMOD',
      'actionType': 'automod_block',
      'reason': 'Blocked upload "$blogTitle" — flagged words: ${matchedWords.join(', ')}',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
