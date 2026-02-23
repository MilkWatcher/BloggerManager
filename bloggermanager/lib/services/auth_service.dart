import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

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
      
      // Create user account ONLY
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('User created: ${userCredential.user?.uid}');

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      debugPrint('Display name updated');
      
      // Create initial Firestore profile
      String userId = userCredential.user!.uid;
      debugPrint('About to create profile for userId: $userId with email: $email');
      try {
        await _firestoreService.createInitialProfile(userId, email, displayName);
        debugPrint('Profile creation succeeded!');
      } catch (firestoreError) {
        debugPrint('PROFILE CREATION FAILED: $firestoreError');
        // Don't fail the signup just because profile creation failed
        // The user can complete it later
      }
      
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
