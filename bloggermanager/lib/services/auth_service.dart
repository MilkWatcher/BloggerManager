import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Create user account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);

      // Create initial blogger profile in Firestore with "Pending" status
      await _firestore.collection('bloggers').doc(userCredential.user!.uid).set({
        'userId': userCredential.user!.uid,
        'email': email,
        'displayName': displayName,
        'location': const GeoPoint(0, 0),
        'domain_link': '',
        'profile_details': '',
        'tags': [],
        'verification_status': 'Pending',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      return (true, 'Account created successfully!');
    } on FirebaseAuthException catch (e) {
      return (false, e.message ?? 'Signup failed');
    } catch (e) {
      return (false, 'An error occurred: $e');
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
