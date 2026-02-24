# Blogger Manager - Firebase Security Rules Guide

## Overview

Firestore Security Rules control who can access what data in your database. These rules are evaluated on the Firebase backend and cannot be bypassed by client-side code.

## Key Security Principles for Blogger Manager

### 1. **Authentication Required**
- Users must be logged in to read or write any data
- No anonymous access permitted

### 2. **User Data Isolation**
- Users can only modify their own profile
- Users cannot read/write other users' private information
- All profiles can be read by any authenticated user (public discovery)

### 3. **Data Integrity**
- Cannot modify `uid`, `email`, or `createdAt` (immutable fields)
- Cannot delete profiles (use soft deletes via admin)
- Profile creation must include required fields

## Security Rules Breakdown

### Users Collection `/users/{userId}`

```firestore
// READ ACCESS
allow read: if isAuthenticated();
```
✅ Any logged-in user can read any blogger's profile
- Enables discovery feature
- Supports search and filtering

```firestore
// CREATE ACCESS
allow create: if isAuthenticated() && 
               isUserOwner(userId) && 
               isValidBloggerData() &&
               request.resource.data.verificationStatus == 'Approved';
```
✅ Users can only create their own profile
✅ Profile must have `uid`, `email`, `displayName`
✅ New profiles automatically set to 'Approved' status

```firestore
// UPDATE ACCESS
allow update: if isAuthenticated() && 
              isUserOwner(userId) && 
              isValidBloggerData();
```
✅ Users can only update their own profile
✅ Cannot change immutable fields (`uid`, `email`, `createdAt`)
✅ Can update: displayName, profileDetails, domainLink, location, tags

```firestore
// DELETE ACCESS
allow delete: if false;
```
❌ Profiles cannot be deleted directly
- Prevents accidental data loss
- Admin can soft-delete via custom functions

## Helper Functions

### `isAuthenticated()`
```firestore
function isAuthenticated() {
  return request.auth.uid != null;
}
```
Checks if user is logged in.

### `isUserOwner(userId)`
```firestore
function isUserOwner(userId) {
  return request.auth.uid == userId;
}
```
Checks if the authenticated user is the document owner.

### `isValidBloggerData()`
```firestore
function isValidBloggerData() {
  let hasRequiredFields = request.resource.data.keys().hasAll(
    ['uid', 'email', 'displayName']
  );
  let noForbiddenUpdates = !request.resource.data.keys().hasAny(
    ['uid', 'email', 'createdAt']
  );
  return hasRequiredFields && noForbiddenUpdates;
}
```
Validates that:
- Required fields are present
- Immutable fields are not being modified

## How to Deploy Security Rules

### Option 1: Firebase Console (Web)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the security rules
5. Click **Publish**

### Option 2: Firebase CLI
```bash
# Login to Firebase
firebase login

# Deploy rules
firebase deploy --only firestore:rules

# Test rules locally
firebase emulators:start --only firestore
```

### Option 3: Use Provided File
```bash
# Copy the rules to your Firebase project folder
cp firestore_security_rules.txt firestore.rules

# Deploy
firebase deploy --only firestore:rules
```

## Testing Security Rules

### Using Firebase Emulator (Recommended for Development)

```bash
# Start emulator
firebase emulators:start --only firestore

# Access emulator at localhost:8080
```

### Test Cases

#### ✅ Read Blogger Profile (Should Pass)
```
Condition: User is logged in
Action: Read any user's profile
Expected: Success
```

#### ✅ Update Own Profile (Should Pass)
```
Condition: User is logged in
Action: Update their own displayName and tags
Expected: Success
```

#### ❌ Update Other User's Profile (Should Fail)
```
Condition: User is logged in
Action: Try to update another user's profile
Expected: Permission denied
```

#### ❌ Modify Email Field (Should Fail)
```
Condition: User is logged in
Action: Try to change own email in update
Expected: Permission denied (immutable field)
```

#### ❌ Read Without Auth (Should Fail)
```
Condition: User is NOT logged in
Action: Try to read any profile
Expected: Permission denied
```

## Firestore Data Structure with Security

```
users/
├── {userId} (document)
│   ├── uid: string (immutable)
│   ├── email: string (immutable)
│   ├── displayName: string (writable by owner)
│   ├── location: GeoPoint (writable by owner)
│   ├── domainLink: string (writable by owner)
│   ├── profileDetails: string (writable by owner)
│   ├── tags: array (writable by owner)
│   ├── verificationStatus: string (auto-set on create)
│   ├── createdAt: timestamp (immutable)
│   ├── updatedAt: timestamp (auto-updated)
│   └── lastLoginAt: timestamp (auto-updated)
```

## Future Security Enhancements

### 1. Role-Based Access Control (RBAC)
```firestore
// Add custom claims to user tokens
{
  uid: "user123",
  role: "blogger|publisher|moderator|admin"
}

// Extend rules
function hasRole(role) {
  return request.auth.token.role == role;
}

// Example: Only moderators can approve profiles
match /users/{userId} {
  allow update: if hasRole('moderator') && 
                   request.resource.data.verificationStatus in ['Approved', 'Denied'];
}
```

### 2. Rate Limiting
```firestore
// Prevent spam reviews
match /ratings/{ratingId} {
  allow create: if isAuthenticated() && 
                   request.time < resource.data.createdAt + duration.value(86400, 's');
}
```

### 3. Field-Level Security
```firestore
// Hide sensitive fields from non-owners
function canViewSensitiveFields(userId) {
  return isUserOwner(userId) || hasRole('admin');
}

match /users/{userId} {
  allow read: if isAuthenticated() && 
                  (canViewSensitiveFields(userId) || 
                   !request.resource.data.keys().hasAny(['socialHandles', 'phone']));
}
```

### 4. Soft Delete Pattern
```firestore
// Mark as deleted instead of removing
match /users/{userId} {
  allow delete: if hasRole('admin');
  
  allow read: if isAuthenticated() && 
                 resource.data.get('deletedAt', null) == null;
}
```

## Common Security Mistakes to Avoid

### ❌ Allow Everyone Read Access
```firestore
// DON'T DO THIS
match /users/{userId} {
  allow read: if true;  // No authentication required!
}
```

### ❌ Allow Write Without Validation
```firestore
// DON'T DO THIS
match /users/{userId} {
  allow write: if request.auth.uid != null;  // No data validation
}
```

### ❌ Allow Update on All Fields
```firestore
// DON'T DO THIS
match /users/{userId} {
  allow update: if isUserOwner(userId);  // Can change anything!
}
```

### ✅ Best Practice
```firestore
// DO THIS - Validate data structure and immutable fields
match /users/{userId} {
  allow update: if isUserOwner(userId) && 
                   isValidBloggerData() &&
                   !request.resource.data.keys().hasAny(['uid', 'email', 'createdAt']);
}
```

## Monitoring and Debugging

### View Rule Violations
1. Firebase Console → Firestore → Rules
2. Check "Rules Playground"
3. Test specific read/write operations

### Enable Firestore Debug Logging
```dart
// In Flutter app
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  sslEnabled: false,  // Only for local testing!
);
```

## Deployment Checklist

- [ ] Security rules reviewed
- [ ] Test cases passed in emulator
- [ ] No `allow read: if true` anywhere
- [ ] All writes validate data
- [ ] Immutable fields protected
- [ ] User data isolation enforced
- [ ] Rules deployed to production Firebase
- [ ] Tested against live app

## Example: Complete Deployment

```bash
# 1. Start emulator
firebase emulators:start --only firestore

# 2. Run app against emulator (in Flutter)
# Update main.dart to use emulator

# 3. Test app functionality
# - Signup ✓
# - Edit profile ✓
# - View other profiles ✓
# - Search/discover ✓

# 4. Deploy to production
firebase deploy --only firestore:rules

# 5. Verify in console
# Firebase Console → Firestore → Rules
```

## Support and Questions

For questions about these security rules, refer to:
- [Firebase Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Firestore Security Best Practices](https://firebase.google.com/docs/firestore/security/rules-query)
- [Firebase Rules Playground](https://console.firebase.google.com/project/_/firestore/rules)
