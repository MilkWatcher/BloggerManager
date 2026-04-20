import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:developer' as developer;

import '../models/blogger_user.dart';
import '../models/user_notification.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  User? get currentUser => _auth.currentUser;

  Future<BloggerUser?> getCurrentBloggerUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return BloggerUser.fromJson(doc.data()!, user.uid);
      }
      return null;
    } catch (e) {
      developer.log('Error getting current blogger user: $e', error: e, name: 'AuthService');
      return null;
    }
  }

  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'blogger';

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['role'] as String? ?? 'blogger';
    } catch (e) {
      developer.log('Error getting user role: $e', error: e, name: 'AuthService');
      return 'blogger';
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found.');
    }

    // Re-authenticate before changing password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> clearMustChangePassword() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'mustChangePassword': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns (isBanned, banExpiry, banReason) for the current user.
  /// If the ban has expired, auto-unbans the user.
  Future<({bool isBanned, DateTime? banExpiry})> checkCurrentUserBanStatus() async {
    final user = _auth.currentUser;
    if (user == null) return (isBanned: false, banExpiry: null);

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return (isBanned: false, banExpiry: null);

      final String status = data['status'] as String? ?? 'active';
      if (status != 'banned') return (isBanned: false, banExpiry: null);

      final DateTime? banExpiry = (data['banExpiry'] as Timestamp?)?.toDate();
      if (banExpiry == null) return (isBanned: false, banExpiry: null);

      // Auto-unban if expired
      if (banExpiry.isBefore(DateTime.now())) {
        await _firestore.collection('users').doc(user.uid).set({
          'status': 'active',
          'banExpiry': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return (isBanned: false, banExpiry: null);
      }

      return (isBanned: true, banExpiry: banExpiry);
    } catch (e) {
      developer.log('Error checking ban status: $e', error: e, name: 'AuthService');
      return (isBanned: false, banExpiry: null);
    }
  }

  Future<List<UserNotification>> getUnacknowledgedNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('acknowledged', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => UserNotification.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Error getting notifications: $e', error: e, name: 'AuthService');
      return [];
    }
  }

  Future<void> acknowledgeNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'acknowledged': true});
  }
}
