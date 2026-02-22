# 🚀 Blogger Manager - Web Platform

A Flutter web application connecting niche local content creators with regional newspaper publishers.

## 📋 Features

✅ **Blogger Authentication**
- Secure email/password signup and login
- Automatic profile creation on signup

✅ **Profile Dashboard**
- Bio/description with social handles
- Blog/portfolio link
- Geographic location (GeoPoint for local discovery)
- Content tags for categorization

✅ **Admin Verification**
- Profiles start as "Pending"
- Admin approval workflow
- Approved profiles visible to publishers

✅ **Geographic Database**
- Storage by location (GeoPoint)
- Local content creator discovery
- Regional search capabilities

## 🔧 Setup Instructions

### Step 1: Get Firebase Credentials

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: `bloggermanager-f1e21`
3. Click **Settings** (⚙️) → **Project Settings**
4. Scroll to "Your Apps" section
5. Find "Web" app (or create one if needed)
6. Copy the config:
   - `apiKey`
   - `appId`
   - `messagingSenderId`

### Step 2: Update firebase_options.dart

Edit `lib/firebase_options.dart` and replace:
```dart
apiKey: 'YOUR_API_KEY',           // Paste apiKey
appId: 'YOUR_APP_ID',              // Paste appId
messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',  // Paste messagingSenderId
```

### Step 3: Set Firestore Security Rules

1. Go to Firebase Console
2. Select `bloggermanager-f1e21`
3. Go to **Firestore Database** → **Rules**
4. Replace with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Bloggers collection
    match /bloggers/{userId} {
      // Users can read/write their own profile
      allow read, write: if request.auth.uid == userId;
      
      // Allow reading approved profiles publicly
      allow read: if resource.data.verification_status == 'Approved';
    }
  }
}
```

### Step 4: Enable Authentication

1. Go to **Authentication** in Firebase Console
2. Click **Email/Password**
3. Enable it

### Step 5: Create Firestore Database

1. Go to **Firestore Database**
2. Click **Create Database**
3. Start in **production mode**
4. Location: choose closest to you
5. Click **Create**

### Step 6: Run the App

```bash
cd "c:\Users\iphon\Blogger Manager\BloggerManager\bloggermanager"
flutter run -d web  # Run on web
```

Or for mobile:
```bash
flutter run  # Uses connected device or emulator
```

## 📊 Database Schema

### Collection: `bloggers`

Each document has userId as ID:

```javascript
{
  userId: string,                    // From Firebase Auth
  email: string,
  displayName: string,
  profile_details: string,           // Bio + social handles
  domain_link: string,               // Blog/portfolio URL
  location: GeoPoint,                // {latitude, longitude}
  tags: array,                       // ["Politics", "Food", etc]
  verification_status: string,       // "Pending" | "Approved" | "Denied"
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## 🎯 User Flow

### For Bloggers:

1. **Sign Up** → Create account with email
2. **Auto-profile created** → Status: "Pending"
3. **Fill Dashboard** → Bio, link, location, tags
4. **Submit** → Status stays "Pending" (awaiting admin)
5. **Get Approved** → Profile visible to publishers
6. **Get Found** → Publishers can search by location/tags

### For Admins:

1. View all pending profiles
2. Approve (status → "Approved")
3. Or Deny (status → "Denied")
4. Publishers can then read approved profiles via search

## 🔐 Security Notes

- Users can only modify their own profile
- Profiles are private until approved
- Only approved profiles are discoverable
- Admin functions require separate admin role (future enhancement)

## 📱 Platform Support

- ✅ Web (primary for v1)
- ✅ Android
- ✅ iOS
- ⏳ Windows/macOS (supported via Flutter)

## 🚀 Running on Web

```bash
flutter run -d web --web-hostname localhost --web-port 5000
```

Then visit: `http://localhost:5000`

## 📚 Project Structure

```
lib/
├── main.dart                    # App entry & auth wrapper
├── firebase_options.dart        # Firebase config (UPDATE THIS!)
├── models/
│   └── blogger_profile.dart    # Data model
├── services/
│   ├── auth_service.dart       # Firebase Auth
│   ├── firestore_service.dart  # Firestore ops
│   └── app_provider.dart       # State management
└── screens/
    ├── login_screen.dart       # Login UI
    ├── signup_screen.dart      # Signup UI
    └── profile_dashboard_screen.dart  # Profile editing
```

## 🐛 Troubleshooting

### "Cannot connect to Firebase"
- Make sure `firebase_options.dart` has real credentials
- Check project ID is correct
- Verify Firestore database was created

### "Permission denied" errors
- Check Firestore security rules are set correctly
- Make sure you're authenticated
- Verify you're reading your own profile or an approved profile

### Location permission denied
- On web: Open DevTools → Application → ensure geolocation enabled
- On Android: Grant location permission in app settings
- On iOS: Add location permissions to Info.plist

## 🎓 Next Steps

1. **Admin Dashboard**
   - View pending profiles
   - Approve/Deny with comments
   - Manage publishers

2. **Publisher Features**
   - Search by location/tags
   - Browse approved bloggers
   - Contact/collaboration requests

3. **Notifications**
   - Email on profile approval
   - When publishers contact
   - New matching bloggers

4. **Analytics**
   - Track profile views
   - Search insights
   - Collaboration rates

## 📞 API Summary

### AuthService
```dart
signUp(email, password, displayName)  // Create account
login(email, password)                 // Login
logout()                               // Logout
resetPassword(email)                   // Password reset
```

### FirestoreService
```dart
getBloggerProfile(userId)              // Get own profile
updateBloggerProfile(userId, data)     // Update profile
getApprovedBloggers()                  // List approved
searchBloggersByTag(tag)               // Search by tag
getPendingBloggers()                   // Admin: pending list
updateVerificationStatus(userId, status) // Admin: approve
```

## 📄 License

Private project - Blogger Manager

---

**Need help?** Check the error message, review this README, or consult [Flutter Docs](https://flutter.dev) and [Firebase Docs](https://firebase.google.com/docs)
