# Firestore Security Rules for Admin Dashboard

The admin dashboard needs read access to display data from Firestore. Update your security rules in the Firebase Console.

## How to Update Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **women-safety-analytics-a-dabd0**
3. Click on **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Replace the existing rules with the rules below
6. Click **Publish**

## Recommended Rules for Testing

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - allow public read for admin dashboard
    match /users/{userId} {
      allow read: if true;  // Allow admin dashboard to read
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // User's safety zones subcollection
      match /zones/{zoneId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      // User's emergency contacts subcollection
      match /contacts/{contactId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // SOS Alerts collection - allow public read for admin dashboard
    match /sos_alerts/{alertId} {
      allow read: if true;  // Allow admin dashboard to read
      allow write: if request.auth != null;
    }
    
    // Diagnostics collection
    match /diagnostics/{docId} {
      allow read, write: if request.auth != null;
    }

    // Collection Group Query for Zones (Global Visibility)
    match /{path=**}/zones/{zoneId} {
      allow read: if request.auth != null;
    }
  }
}
```

## Production Rules (More Secure)

For production, you should restrict admin dashboard access to authenticated admin users:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is admin
    function isAdmin() {
      return request.auth != null && 
             get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAdmin() || (request.auth != null && request.auth.uid == userId);
      allow write: if request.auth != null && request.auth.uid == userId;
      
      match /zones/{zoneId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /contacts/{contactId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // SOS Alerts
    match /sos_alerts/{alertId} {
      allow read: if isAdmin() || request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Admins collection
    match /admins/{adminId} {
      allow read: if request.auth != null && request.auth.uid == adminId;
      allow write: if false; // Only set via Firebase Console
    }

    // Global Zones Read Access
    match /{path=**}/zones/{zoneId} {
      allow read: if request.auth != null;
    }
  }
}
```

## After Updating Rules

1. Refresh the admin dashboard: http://localhost:8000
2. Open browser console (F12) to verify no permission errors
3. You should see live data from Firestore!

## Current Error

The dashboard is showing:
- `Error fetching SOS alerts: FirebaseError: Missing or insufficient permissions.`
- `Error fetching users: FirebaseError: Missing or insufficient permissions.`

This will be fixed once you update the security rules as shown above.
