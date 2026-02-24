# Blogger Manager - Architecture & Implementation Guide

## Application Overview

The Blogger Manager application is a Flutter-based platform that connects local content creators (bloggers) with regional newspaper publishers. It provides a moderated, searchable geographic database to help small-town bloggers get noticed and help local newspapers find local stories.

## Core Architecture

### 1. Authentication Layer
- **Technology**: Firebase Authentication
- **Features**:
  - Email/password authentication
  - User registration (signup)
  - Login functionality
  - Session management via Flutter StreamBuilder

### 2. Data Layer
- **Technology**: Cloud Firestore
- **Collection**: `users`
  - Stores complete blogger profiles
  - Real-time synchronization
  - Geo-location support via GeoPoint

### 3. Model Layer
- **BloggerUser** (`models/blogger_user.dart`)
  - Comprehensive user data model
  - JSON serialization/deserialization
  - Copy-with pattern for immutability

### 4. Service Layer
- **BloggerService** (`services/blogger_service.dart`)
  - Centralized business logic
  - Database operations abstraction
  - Search and filtering functionality
  - Location-based calculations

### 5. UI Layer (Screens)
- **Edit Profile Screen** - Profile management
- **Discover Bloggers Screen** - Browse and search
- **Moderation Dashboard** - Admin reviews
- **Profile Dashboard** - Main app with navigation

## Data Flow

### User Registration Flow
```
signup input → Firebase Auth CreateUserWithEmailAndPassword
             → Firestore users collection document created
             → BloggerUser model initialized with "Pending" status
             → User redirected to profile dashboard
```

### Blogger Discovery Flow
```
Discover Screen → BloggerService.getApprovedBloggers()
               → Firestore query (verificationStatus == "Approved")
               → BloggerUser objects instantiated
               → Display in ListView with filtering capability
```

### Profile Update Flow
```
Edit Form → BloggerService.updateBloggerProfile()
          → Firestore document update (merge: true)
          → Real-time listener triggers update
          → UI refreshes with StreamBuilder
```

### Moderation Flow
```
Moderation Dashboard → BloggerService.getPendingBloggers()
                    → Display pending users
                    → Admin clicks Approve/Deny
                    → verificationStatus updated in Firestore
                    → Pending list refreshed
```

## Key Features Implementation

### 1. Geo-location Support
```dart
// Storage
GeoPoint location = GeoPoint(latitude, longitude)

// Retrieval & Calculation
distance = _calculateDistance(
  centerLat, centerLon,
  bloggerLat, bloggerLon
)
```

### 2. Tag-based Search
```dart
// Filter by multiple tags using arrayContainsAny
firestore
  .where('tags', arrayContainsAny: ['Politics', 'Food'])
  .get()
```

### 3. Verification States
- **Pending**: New blogger awaiting moderation
- **Approved**: Verified blogger visible to public
- **Denied**: Rejected blogger (hidden from discovery)

### 4. Real-time Updates
```dart
StreamBuilder<DocumentSnapshot>
  .stream(firestore.collection('users').doc(uid).snapshots())
```

## Navigation Structure

```
AuthGate (Authentication Check)
│
├─ NO USER
│  └─ AuthScreen (Login/Signup)
│     └─ Firestore user creation
│
└─ USER LOGGED IN
   └─ ProfileDashboardScreen (Main App)
      ├─ Bottom Navigation Tab 0: My Profile
      │  ├─ View profile (StreamBuilder)
      │  └─ Edit profile (Navigator.push)
      │
      ├─ Bottom Navigation Tab 1: Discover
      │  ├─ Browse all approved bloggers
      │  ├─ Filter by tags
      │  └─ View detailed profiles
      │
      └─ Bottom Navigation Tab 2: Moderation
         ├─ View pending applications
         ├─ Approve bloggers
         └─ Deny bloggers
```

## State Management Approach

The application uses:
- **StatefulWidget** for screens with user interactions
- **StreamBuilder** for real-time Firestore data
- **setState()** for local UI updates
- **Mounted checks** for safe async operations

```dart
// Pattern: Async operation with safety
Future<void> _operation() async {
  setState(() => _isLoading = true);
  try {
    await _service.doSomething();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(...);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(...);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

## Error Handling

- **Firebase Auth Errors**: Caught and displayed via SnackBar
- **Firestore Errors**: Logged via developer.log, user-friendly messages shown
- **Validation**: Input validation before operations
- **Network**: Firestore offline support via local caching

## Performance Considerations

1. **Queries**
   - Index on verificationStatus + order by createdAt
   - arrayContainsAny for tag searches
   - Null checks for location-based filtering

2. **Real-time Listen**
   - StreamBuilder rebuilds on Firestore updates
   - Mounted checks prevent memory leaks
   - Proper disposal of controllers

3. **UI Optimization**
   - ListView.builder for blogger lists
   - Lazy loading of profiles
   - Card-based layout for efficiency

## Security Considerations

For production, implement:
- **Firestore Security Rules**
  ```
  match /users/{document=**} {
    allow read: if request.auth.uid != null;
    allow write: if request.auth.uid == document;
    allow read, write: if hasRole('moderator');
  }
  ```

- **User Roles** (future enhancement)
  - Regular blogger
  - Publisher
  - Moderator
  - Admin

## Available Content Categories (Tags)

```dart
[
  'Politics',
  'Food',
  'Cats',
  'Travel',
  'Technology',
  'Business',
  'Lifestyle',
  'Sports',
  'Health',
  'Entertainment',
  'Education',
  'DIY',
  'Fashion',
  'Photography',
  'Music',
]
```

## Future Enhancement Opportunities

1. **Advanced Location Features**
   - Geohashing for efficient geographic queries
   - Map integration (Google Maps)
   - Postal code / Eircode support

2. **Messaging System**
   - Direct messaging between bloggers and publishers
   - Message notifications

3. **Content Management**
   - Portfolio showcase
   - Blog article linking
   - Media uploads

4. **Discovery Features**
   - Advanced filters
   - Trending bloggers
   - Recommendations
   - Saved profiles

5. **Analytics**
   - View count tracking
   - Popular topics
   - Geographic heat maps
   - User engagement metrics

6. **Gamification**
   - User ratings and reviews
   - Achievement badges
   - Verification badges
   - Trust scores

7. **Social Features**
   - Following system
   - Comments and discussions
   - Share profiles
   - Notifications

## Testing Strategy

Recommended test coverage:
- **Unit Tests**: BloggerUser model, BloggerService methods
- **Widget Tests**: Individual screen components
- **Integration Tests**: Auth flow, CRUD operations
- **Firebase Emulator**: Local testing without Firebase costs

## Deployment Notes

1. **Android**
   - Configure Firebase Console project
   - Set SHA-1 fingerprints
   - Build release APK/AAB

2. **iOS**
   - iOS deployment target: 11.0+
   - Configure Firebase provisioning profiles

3. **Web**
   - Add web platform support via `flutter config --enable-web`
   - Configure Firebase web app

4. **Desktop (Windows/macOS/Linux)**
   - Enable platform: `flutter config --enable-[windows|macos|linux]`
   - Test on target platform
