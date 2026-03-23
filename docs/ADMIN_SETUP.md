# Admin Setup Guide

## Initial Admin Account Setup

Since admin seeding is done manually via the Firebase Console, follow these steps to create the default admin account.

### Step 1: Create the Auth User

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **bloggermanager-f1e21**
3. Navigate to **Authentication** > **Users**
4. Click **Add user**
5. Enter:
   - **Email:** `admin@email.com`
   - **Password:** `admin123`
6. Click **Add user** and copy the generated **User UID**

### Step 2: Create the Firestore User Document

1. Navigate to **Firestore Database**
2. Select the **default** database
3. Go to the **users** collection (create it if it doesn't exist)
4. Click **Add document**
5. Set the **Document ID** to the **User UID** from Step 1
6. Add the following fields:

| Field                  | Type      | Value              |
|------------------------|-----------|--------------------|
| `uid`                  | string    | *(the User UID)*   |
| `email`                | string    | `admin@email.com`  |
| `displayName`          | string    | `Admin`            |
| `role`                 | string    | `admin`            |
| `status`               | string    | `active`           |
| `mustChangePassword`   | boolean   | `true`             |
| `profileSetupCompleted`| boolean   | `true`             |
| `verificationStatus`   | string    | `Approved`         |
| `createdAt`            | timestamp | *(current time)*   |
| `updatedAt`            | timestamp | *(current time)*   |
| `tags`                 | array     | `[]`               |

### Step 3: First Login

1. Open the Blogger Manager app
2. Login with `admin@email.com` / `admin123`
3. You will be forced to change your password before proceeding
4. After changing the password, you'll see the app with 4 tabs including **Moderation**

### Step 4: Assign Moderators

1. Go to the **Moderation** tab
2. Select the **Role Management** tab
3. Toggle the switch next to any blogger to promote them to moderator
4. Moderators will see the Moderation tab on their next login

---

## Roles Overview

| Role       | Access                                                       |
|------------|--------------------------------------------------------------|
| **Admin**  | Full access + Role Management tab (can assign moderators)    |
| **Moderator** | All moderation tabs except Role Management                |
| **Blogger** | Standard app (Home, My Profile, Bloggers — 3 tabs)         |

## Security Constraints

- Only admins can assign/remove moderator roles
- Moderators cannot ban, warn, or delete admins or other moderators
- All moderation actions are logged in the `moderation_logs` collection
- Bloggers cannot modify their own `role`, `status`, or `banExpiry` fields
