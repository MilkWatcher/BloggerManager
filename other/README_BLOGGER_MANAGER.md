# Blogger Manager Application

## Overview

Blogger Manager is a web/mobile platform designed to connect niche local content creators and regional newspaper publishers. It provides a safe, moderated, searchable, geographic database that helps:

- **Small-town bloggers** get noticed and reach more people
- **Local newspapers** discover new talent and local stories
- **Users** find local writers in their areas with specific interests

## Key Features

### 1. **User Authentication**
- Email/password authentication with Firebase
- User registration and login
- Profile creation and management

### 2. **Blogger Profiles**
Comprehensive blogger profiles with:
- **Display Name** - Blogger's name
- **Location** - GeoPoint coordinates (latitude/longitude)
- **Domain Link** - Website or blog URL
- **Profile Details** - Bio and personal information
- **Tags** - Multiple interest areas (Politics, Food, Cats, Travel, Technology, etc.)
- **Verification Status** - Pending, Approved, or Denied by moderators

### 3. **Blogger Discovery**
- Browse all approved bloggers
- Filter and search by topics/tags
- View detailed blogger profiles with:
  - Verification status
  - Contact information
  - Topics of interest
  - Location coordinates
  - Website links

### 4. **Moderation Dashboard**
For platform moderators:
- Review pending blogger applications
- Approve or deny applications
- View detailed application information
- Ensure quality and safety of the platform

### 5. **Geographic Features**
- Store blogger locations using GeoPoint
- Support for latitude/longitude coordinates
- Basic distance calculation using Haversine formula
- Location-based search capabilities (framework ready)

## Project Structure

```
lib/
├── main.dart                          # Main app with auth gate and navigation
├── models/
│   └── blogger_user.dart             # BloggerUser data model
├── services/
│   └── blogger_service.dart          # Business logic for blogger operations
├── screens/
│   ├── edit_blogger_profile_screen.dart      # Blogger profile editing
│   ├── discover_bloggers_screen.dart         # Browse and search bloggers
│   └── moderation_dashboard_screen.dart      # Admin moderation interface
├── firebase_options.dart             # Firebase configuration
└── [existing Firebase structure]
```

## Data Model

### BloggerUser
```dart
BloggerUser {
  userId: String (Reference)
  email: String
  displayName: String
  location: GeoPoint? (latitude, longitude)
  domainLink: String?
  profileDetails: String? (bio, social handles)
  tags: List<String> (e.g., ["Politics", "Food", "Cats"])
  verificationStatus: String ("Pending", "Approved", "Denied")
  createdAt: DateTime
  updatedAt: DateTime
  lastLoginAt: DateTime?
}
```

## Firestore Collection Structure

```
users/
├── {userId}/
│   ├── uid: String
│   ├── email: String
│   ├── displayName: String
│   ├── location: GeoPoint
│   ├── domainLink: String
│   ├── profileDetails: String
│   ├── tags: Array
│   ├── verificationStatus: String
│   ├── createdAt: Timestamp
│   ├── updatedAt: Timestamp
│   └── lastLoginAt: Timestamp
```

## Available Topics/Tags

The platform supports the following content categories:
- Politics
- Food
- Cats
- Travel
- Technology
- Business
- Lifestyle
- Sports
- Health
- Entertainment
- Education
- DIY
- Fashion
- Photography
- Music

## Navigation Structure

The app uses bottom navigation with three main sections:

1. **My Profile** (Tab 0)
   - View personal blogger profile
   - Edit profile information
   - Update location, tags, website
   - Check verification status

2. **Discover** (Tab 1)
   - Browse all approved bloggers
   - Filter by topics/tags
   - View blogger details
   - Find local writers

3. **Moderation** (Tab 2)
   - Review pending bloggers
   - Approve or deny applications
   - Ensure platform safety

## Services

### BloggerService
Centralized service for all blogger-related operations:
- `getBlogger()` - Get single blogger
- `updateBloggerProfile()` - Update profile information
- `getApprovedBloggers()` - Get all approved bloggers
- `searchByTags()` - Search by content topics
- `searchByLocation()` - Geographic search (Haversine)
- `getPendingBloggers()` - Get pending reviews
- `approveBlogger()` - Approve blogger
- `denyBlogger()` - Deny blogger

## Setup & Installation

1. **Prerequisites**
   - Flutter 3.11.0 or higher
   - Firebase project setup
   - Firestore database initialized

2. **Installation Steps**
   ```bash
   flutter pub get
   flutter run
   ```

3. **Firebase Configuration**
   - Ensure `firebase_options.dart` is properly configured
   - Update Firestore security rules for user access

4. **Environment Setup**
   - Android/iOS native setup (if building for mobile)
   - Windows desktop setup (if building for desktop)

## Future Enhancements

- [ ] Google Maps integration for better location selection
- [ ] Geohashing for efficient geographic queries
- [ ] Advanced search filters
- [ ] Messaging between bloggers and publishers
- [ ] Blogger portfolio showcase
- [ ] File/image uploads
- [ ] Review and rating system
- [ ] Analytics dashboard
- [ ] Social media integration
- [ ] Email verification
- [ ] Two-factor authentication

## Dependencies

- **firebase_core**: Firebase initialization
- **cloud_firestore**: Database
- **firebase_auth**: Authentication
- **flutter**: UI framework

## Notes

- The application uses Firestore's real-time updates for seamless data synchronization
- All user data is stored in Firestore with proper access control
- The moderation dashboard is available to all users (consider adding role-based access in production)
- Location-based search uses Haversine formula for distance calculation
