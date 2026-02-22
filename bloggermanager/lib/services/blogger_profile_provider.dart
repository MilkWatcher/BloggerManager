import 'package:flutter/foundation.dart';
import '../models/blogger_profile.dart';
import 'firestore_service.dart';

/// State management provider for blogger profiles
class BloggerProfileProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  BloggerProfile? _currentProfile;
  List<BloggerProfile> _profiles = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  BloggerProfile? get currentProfile => _currentProfile;
  List<BloggerProfile> get profiles => _profiles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Create a new blogger profile
  Future<String?> createBloggerProfile(BloggerProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String profileId = await _firestoreService.createBloggerProfile(profile);
      _currentProfile = profile.copyWith(id: profileId);
      _isLoading = false;
      notifyListeners();
      return profileId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update the current blogger profile
  Future<bool> updateBloggerProfile(
      String profileId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateBloggerProfile(profileId, updates);
      
      // Update local current profile if it's the same ID
      if (_currentProfile?.id == profileId) {
        _currentProfile = _currentProfile!.copyWith(
          name: updates['name'] ?? _currentProfile!.name,
          bio: updates['bio'] ?? _currentProfile!.bio,
          profileImageUrl:
              updates['profileImageUrl'] ?? _currentProfile!.profileImageUrl,
          categories: updates['categories'] ?? _currentProfile!.categories,
        );
      }

      // Update in the profiles list
      int index = _profiles.indexWhere((p) => p.id == profileId);
      if (index != -1) {
        _profiles[index] = _profiles[index].copyWith(
          name: updates['name'] ?? _profiles[index].name,
          bio: updates['bio'] ?? _profiles[index].bio,
          profileImageUrl:
              updates['profileImageUrl'] ?? _profiles[index].profileImageUrl,
          categories: updates['categories'] ?? _profiles[index].categories,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch a single blogger profile
  Future<void> fetchBloggerProfile(String profileId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentProfile =
          await _firestoreService.getBloggerProfile(profileId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch all blogger profiles
  Future<void> fetchAllBloggerProfiles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profiles = await _firestoreService.getAllBloggerProfiles();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search for profiles
  Future<void> searchProfiles(String query) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profiles = await _firestoreService.searchBloggerProfiles(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a blogger profile
  Future<bool> deleteBloggerProfile(String profileId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteBloggerProfile(profileId);
      _profiles.removeWhere((p) => p.id == profileId);
      if (_currentProfile?.id == profileId) {
        _currentProfile = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Set current profile
  void setCurrentProfile(BloggerProfile profile) {
    _currentProfile = profile;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
