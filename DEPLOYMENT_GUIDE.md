# Deploying Firebase Security Rules

To deploy the security rules to your Firebase project, you have two options:

## Option 1: Deploy via Firebase CLI (Recommended)

1. Make sure Firebase CLI is installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project (if not already done):
   ```bash
   firebase init firestore
   ```
   - Select "Use an existing project"
   - When asked about `firestore.rules`, choose YES to use the existing file

4. Deploy the rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

## Option 2: Manual Deployment via Firebase Console

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the contents of `firestore.rules` file
5. Paste it into the rules editor
6. Click **Publish**

## Verify Rules Deployment

After deploying, verify the rules are working:
1. In Firebase Console, check the "Rules" tab shows the updated rules
2. Run the app and try sending a hub message
3. Check Firestore Console to see if `hub_messages` collection is created
4. Verify that users can read but not modify other users' messages

## Testing the Hub Chat

### Prerequisites
- Location permissions must be granted
- At least 2 devices/emulators for testing
- Both users should be within 10km of each other (or use mock locations for testing)

### Test Steps
1. **Build and run the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Grant location permissions** when prompted

3. **Navigate to Chat screen** and select the "Active Chats" tab

4. **Verify hub UI**:
   - Should see "Location Hub (10km radius)" header
   - Should show user count
   - Should see message input at bottom

5. **Send test messages** from multiple devices

6. **Verify real-time updates** - messages should appear instantly

7. **Test distance filtering**:
   - Use mock locations >10km apart to verify filtering works
   - Messages from distant users should not appear

## Firestore Index Creation

The hub messages query requires a composite index. If you see an index error:

1. Click the link in the error message, OR
2. Manually create the index in Firebase Console:
   - Go to **Firestore Database** → **Indexes**
   - Add the following composite index:
     - Collection: `hub_messages`
     - Fields to index:
       - `expiresAt` (Ascending)
       - `timestamp` (Ascending)
     - Query scope: Collection

## Troubleshooting

### Location Not Working
- Check location permissions in device settings
- Ensure location services are enabled
- Try restarting the app

### Messages Not Appearing
- Check Firebase Console → Firestore to verify messages are being created
- Verify security rules are deployed correctly
- Check console for any error messages

### "Permission Denied" Errors
- Verify user is authenticated (signed in with Google)
- Check security rules are deployed
- Ensure user has `userId` and `blockchainId` in Firestore `users` collection
