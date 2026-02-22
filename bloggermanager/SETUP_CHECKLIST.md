# ⚡ Quick Setup Checklist

Complete these steps to get Blogger Manager running:

## 🔐 Firebase Configuration (5 minutes)

- [X] Open [Firebase Console](https://console.firebase.google.com)
- [X] Select project: `bloggermanager-f1e21`
- [X] Go to Project Settings → Your Apps
- [X] Copy Web app credentials (apiKey, appId, messagingSenderId)
- [X] Paste into `lib/firebase_options.dart`

## 🗄️ Firestore Setup (2 minutes)

- [X] Create Firestore Database (if not exists)
- [X] Go to Rules tab
- [X] Copy security rules from README.md
- [X] Paste and publish

## 🔑 Authentication Setup (1 minute)

- [X] Go to Authentication in Firebase Console
- [X] Enable "Email/Password" provider

## 🚀 Run the App (1 minute)

```bash
cd "c:\Users\iphon\Blogger Manager\BloggerManager\bloggermanager"
flutter run -d web
```

Or mobile:

```bash
flutter run
```

## ✅ Test the Flow

1. Click "Sign Up"
2. Create account with email/password
3. You'll see "Profile incomplete" (Pending status)
4. Fill in your profile:
   - Bio with social handles
   - Blog link (optional)
   - Get location
   - Select tags
5. Click "Save Profile"
6. Message shows awaiting admin approval ✓

## 🎯 Test Admin Approval

Right now you can manually test approval:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Firestore → Collection `bloggers`
3. Find your profile document
4. Edit `verification_status` field
5. Change from "Pending" → "Approved"
6. Refresh app - status updates!

## ❌ Common Issues

**Issue**: Firebase connection error

- **Fix**: Update firebase_options.dart with real credentials

**Issue**: Permission denied error

- **Fix**: Check Firestore security rules are published

**Issue**: Location won't update

- **Fix**: On web, make sure browser location permission is enabled

**Issue**: Can't login after signup

- **Fix**: Check email and password are correct

---

## 📱 Next: Build Admin Panel

Once basic flow works, create admin screens to:

- View pending profiles
- Approve/Deny with one click
- See verification history

---

Once you complete setup, the app is ready to use! 🎉
