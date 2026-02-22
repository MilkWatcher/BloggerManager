import 'package:flutter/foundation.dart';
import '../models/blogger_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  BloggerProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  BloggerProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isLoggedIn => _authService.isLoggedIn;
  String? get userId => _authService.currentUser?.uid;

  /// Load user profile
  Future<void> loadProfile() async {
    if (!isLoggedIn) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _firestoreService.getBloggerProfile(userId!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (!isLoggedIn) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateBloggerProfile(userId!, updates);
      
      // Update local profile
      _profile = _profile?.copyWith(
        location: updates['location'] ?? _profile!.location,
        domainLink: updates['domain_link'] ?? _profile!.domainLink,
        profileDetails: updates['profile_details'] ?? _profile!.profileDetails,
        tags: updates['tags'] ?? _profile!.tags,
      );
      
      _isLoading = false;
      _successMessage = 'Profile updated successfully!';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
