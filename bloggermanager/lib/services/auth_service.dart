import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Sign up with email and password
  Future<(bool success, String message)> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      debugPrint('Starting signup for: $email');
      
      // Create user account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('User created: ${userCredential.user?.uid}');

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      debugPrint('Display name updated');

      // Create initial blogger profile in Firestore with "Pending" status
      final uid = userCredential.user!.uid;
      debugPrint('Creating Firestore profile for: $uid');
      
      await _firestore.collection('bloggers').doc(uid).set({
        'userId': uid,
        'email': email,
        'displayName': displayName,
        'location': const GeoPoint(0, 0),
        'domain_link': '',
        'profile_details': '',
        'tags': [],
        'verification_status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Profile created successfully in Firestore');
      return (true, 'Account created successfully!');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      return (false, 'Auth Error: ${e.message ?? "Signup failed"}');
    } catch (e) {
      debugPrint('Signup Error: $e');
      return (false, 'Error: $e');
    }
  }

  /// Login with email and password
  Future<(bool success, String message)> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return (true, 'Login successful!');
    } on FirebaseAuthException catch (e) {
      return (false, e.message ?? 'Login failed');
    } catch (e) {
      return (false, 'An error occurred: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Password reset
  Future<(bool success, String message)> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return (true, 'Password reset email sent!');
    } on FirebaseAuthException catch (e) {
      return (false, e.message ?? 'Failed to send reset email');
    }
  }
}
