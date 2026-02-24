# Blogger Manager - Getting Started Guide

## Project Structure

```
lib/
├── main.dart                          # App entry point & auth
├── firebase_options.dart              # Firebase configuration
├── models/
│   └── blogger_user.dart             # User data model
├── services/
│   └── blogger_service.dart          # Business logic
└── screens/
    ├── edit_blogger_profile_screen.dart
    ├── discover_bloggers_screen.dart
    └── moderation_dashboard_screen.dart
```

## How to Run the Application

### Prerequisites
- Flutter SDK (3.11.0+)
- Firebase Project configured
- Firestore Database initialized
- Device or emulator set up

### Steps
```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Build for release
flutter build apk    # Android
flutter build ios    # iOS
flutter build web    # Web
```

## Using the Application

### User Registration
1. Launch app → AuthScreen appears
2. Click "Need an account? Sign Up"
3. Enter name, email, password
4. Click "Sign Up"
5. User created in Firestore with "Pending" status

### Editing Your Profile
1. Login → Profile Dashboard Tab
2. Click "Edit Profile"
3. Fill in:
   - Name (required)
   - Bio (optional)
   - Website URL (optional)
   - Location: Latitude & Longitude (optional)
   - Topics: Select relevant tags
4. Click "Save Profile"

### Discovering Bloggers
1. Click "Discover" tab
2. Select topics to filter by
3. Click "Search" or "Reset"
4. Browse filtered results
5. View detailed blogger cards

### Moderating Bloggers (Admin)
1. Click "Moderation" tab
2. Review pending blogger applications
3. Click "Approve" or "Deny"
4. Pull down to refresh pending list

## API Reference

### BloggerUser Model

```dart
// Create instance
BloggerUser blogger = BloggerUser(
  userId: 'user123',
  email: 'blogger@example.com',
  displayName: 'John Doe',
  location: GeoPoint(53.3498° N, 6.2603° W),
  domainLink: 'https://myblog.com',
  profileDetails: 'Local food blogger interested in Irish cuisine',
  tags: ['Food', 'Travel', 'Photography'],
  verificationStatus: 'Approved',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Convert to JSON for Firestore
Map<String, dynamic> json = blogger.toJson();

// Create from Firestore data
BloggerUser blogger = BloggerUser.fromJson(data, userId);

// Copy with modifications
BloggerUser updated = blogger.copyWith(
  displayName: 'Jane Doe',
  tags: ['Food', 'Business'],
);
```

### BloggerService Methods

```dart
final service = BloggerService();

// Get a specific blogger
BloggerUser? blogger = await service.getBlogger('userId');

// Update blogger profile
await service.updateBloggerProfile(
  userId: 'user123',
  displayName: 'John Doe',
  profileDetails: 'Bio text',
  domainLink: 'https://blog.com',
  location: GeoPoint(53.3498, -6.2603),
  tags: ['Food', 'Travel'],
);

// Get all approved bloggers
List<BloggerUser> approved = await service.getApprovedBloggers();

// Search by tags
List<BloggerUser> foodBloggers = await service.searchByTags(
  ['Food', 'Cooking'],
);

// Location-based search (50km radius)
List<BloggerUser> nearby = await service.searchByLocation(
  GeoPoint(53.3498, -6.2603),
  50.0, // radius in km
);

// Admin: Get pending bloggers
List<BloggerUser> pending = await service.getPendingBloggers();

// Admin: Approve blogger
await service.approveBlogger('userId');

// Admin: Deny blogger
await service.denyBlogger('userId');
```

## Example: Adding a New Feature

### Example 1: Add Favorite Bloggers

**Step 1: Update BloggerUser model**
```dart
// Add to lib/models/blogger_user.dart
final bool isFavorited;
final List<String> favorites; // user IDs of favorite bloggers

// Update toJson() and fromJson()
```

**Step 2: Add service method**
```dart
// Add to lib/services/blogger_service.dart
Future<void> favoriteBlogger(String userId, String bloggerIdToFavorite) async {
  await _firestore.collection(_usersCollection).doc(userId).update({
    'favorites': FieldValue.arrayUnion([bloggerIdToFavorite]),
  });
}

Future<void> unfavoriteBlogger(String userId, String bloggerIdToUnfavorite) async {
  await _firestore.collection(_usersCollection).doc(userId).update({
    'favorites': FieldValue.arrayRemove([bloggerIdToUnfavorite]),
  });
}

Future<List<BloggerUser>> getFavoriteBloggers(String userId) async {
  final userDoc = await _firestore
      .collection(_usersCollection)
      .doc(userId)
      .get();
  
  final favorites = List<String>.from(userDoc['favorites'] ?? []);
  
  final results = await Future.wait(
    favorites.map((id) => getBlogger(id)),
  );
  
  return results.whereType<BloggerUser>().toList();
}
```

**Step 3: Update UI**
```dart
// In discover_bloggers_screen.dart, add heart button to each card
IconButton(
  icon: Icon(
    isFavorited ? Icons.favorite : Icons.favorite_border,
    color: isFavorited ? Colors.red : null,
  ),
  onPressed: () => _toggleFavorite(blogger.userId),
)
```

### Example 2: Add Rating System

**Step 1: Create Rating model**
```dart
// lib/models/blogger_rating.dart
class BloggerRating {
  final String ratingId;
  final String bloggerId;
  final String raterId;
  final double rating; // 1-5
  final String review;
  final DateTime createdAt;
  
  // toJson() / fromJson()
}
```

**Step 2: Add service methods**
```dart
// lib/services/blogger_service.dart
Future<void> rateBlogger(
  String bloggerId,
  String raterId,
  double rating,
  String review,
) async {
  final ratingId = _firestore.collection('ratings').doc().id;
  await _firestore.collection('ratings').doc(ratingId).set({
    'bloggerId': bloggerId,
    'raterId': raterId,
    'rating': rating,
    'review': review,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<List<BloggerRating>> getBloggerRatings(String bloggerId) async {
  final snapshot = await _firestore
      .collection('ratings')
      .where('bloggerId', isEqualTo: bloggerId)
      .orderBy('createdAt', descending: true)
      .get();
  
  return snapshot.docs
      .map((doc) => BloggerRating.fromJson(doc.data(), doc.id))
      .toList();
}

Future<double> getBloggerAverageRating(String bloggerId) async {
  final ratings = await getBloggerRatings(bloggerId);
  if (ratings.isEmpty) return 0.0;
  return ratings.fold<double>(
    0,
    (sum, r) => sum + r.rating,
  ) / ratings.length;
}
```

## Firestore Data Structure

### Users Collection
```
/users/{userId}
├── uid: string
├── email: string
├── displayName: string
├── location: GeoPoint (lat, lon)
├── domainLink: string
├── profileDetails: string
├── tags: array
├── verificationStatus: string (Pending|Approved|Denied)
├── createdAt: timestamp
├── updatedAt: timestamp
└── lastLoginAt: timestamp
```

### Firebase Security Rules

```firestore
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read all approved bloggers
    match /users/{document=**} {
      allow read: if request.auth.uid != null && 
                     get(/databases/$(database)/documents/users/$(document)).data.verificationStatus == 'Approved';
      
      // Allow users to read their own profile
      allow read: if request.auth.uid == document;
      
      // Allow users to update their own profile
      allow update: if request.auth.uid == document &&
                       request.resource.data.verificationStatus == resource.data.verificationStatus;
      
      // Allow moderators full access
      allow read, write: if request.auth.token.isModerator == true;
    }
  }
}
```

## Common Issues & Solutions

### Issue: "Target of URI doesn't exist"
**Solution**: Check import paths are using relative paths from lib/ directory
```dart
// Correct
import 'models/blogger_user.dart';
import '../models/blogger_user.dart';

// Incorrect
import 'blogger_user.dart'; // if in different folder
```

### Issue: BuildContext used after async gap
**Solution**: Always check `mounted` after async operations
```dart
try {
  await someAsyncOperation();
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(...);
} catch (e) {
  if (!mounted) return;
  // handle error
}
```

### Issue: Firestore permission denied
**Solution**: Update Firestore security rules to match app requirements
```firestore
allow read: if request.auth.uid != null;
allow write: if request.auth.uid == resource.data.uid;
```

## Performance Tips

1. **Use indexes** for frequently filtered fields
2. **Paginate** large lists (implement later)
3. **Cache** user data locally
4. **Suppress** unused import warnings with `// ignore: unused_import`
5. **Profile** with DevTools for performance bottlenecks

## Next Steps

1. Test on emulator or physical device
2. Set up Firestore indexes for queries
3. Configure Firebase security rules
4. Deploy to Firebase Hosting (web) or app stores
5. Monitor performance with Firebase Analytics
6. Implement user feedback system
7. Add push notifications
8. Implement ad system for monetization
