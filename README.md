# 🛡️ Women Safety Analytics - SOS Safety App

A comprehensive Flutter-based women safety application with real-time SOS alerts, location tracking, emergency contacts, and safety zone monitoring.

## 📱 Features

- **SOS Alert System**: One-tap emergency alert with siren sound
- **Real-time Location Tracking**: Share live location with emergency contacts
- **Emergency Contacts Management**: Quick access to saved contacts
- **Nearby Help**: Find and alert nearby users in emergencies
- **Safety Zones**: Geofencing with entry/exit notifications
- **Chat System**: Secure communication with saved contacts
- **Voice Recording**: Record and store emergency audio
- **Push Notifications**: Real-time alerts via Firebase Cloud Messaging
- **Google Sign-In**: Secure authentication
- **Firebase Integration**: Cloud storage and real-time database

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

1. **Flutter SDK** (version 3.9.2 or higher)
   - Download from: https://docs.flutter.dev/get-started/install
   - Verify installation: `flutter --version`

2. **Android Studio** or **VS Code** with Flutter extensions

3. **Git** for version control

4. **Firebase Account** (free tier is sufficient)

5. **Google Cloud Platform Account** (for Maps API)

---

## 📦 Installation & Setup

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/vedantmohite26/women-safety-analytics-SOS-safety.git
cd women-safety-analytics-SOS-safety
```

### 2️⃣ Install Flutter Dependencies

```bash
flutter pub get
```

This will install all required packages from `pubspec.yaml`.

### 3️⃣ Firebase Setup

#### Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name and follow the setup wizard

#### Step 2: Add Android App to Firebase

1. In Firebase Console, click "Add app" → Select Android
2. Enter package name: Check your `android/app/build.gradle` for `applicationId`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

#### Step 3: Enable Firebase Services

In Firebase Console, enable the following:

- **Authentication** → Sign-in methods → Enable Google Sign-In
- **Cloud Firestore** → Create database (Start in production mode)
- **Firebase Storage** → Create storage bucket
- **Cloud Messaging** → Enable for push notifications

#### Step 4: Configure Firestore Security Rules

Copy the rules from `firestore.rules` file and paste them in Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Your rules from firestore.rules file
  }
}
```

### 4️⃣ Google Maps API Setup

#### Step 1: Get API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable **Maps SDK for Android**
4. Go to **Credentials** → Create API Key
5. Copy the API key

#### Step 2: Add API Key to AndroidManifest.xml

Open `android/app/src/main/AndroidManifest.xml` and replace the existing API key:

```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

> ⚠️ **Current API Key**: `AIzaSyALPqsaDTJYLzWsTyeKRszpOxosz3mqSgs` (Replace with your own!)

### 5️⃣ Add Audio Assets

Ensure the siren sound file is present:

```
assets/
  └── sounds/
      └── siren.mp3
```

If missing, add your siren audio file to this directory.

---

## 🔑 Required API Keys & Configuration

### Summary of Required Keys

| Service | Key Location | How to Get |
|---------|--------------|------------|
| **Firebase** | `android/app/google-services.json` | [Firebase Console](https://console.firebase.google.com/) |
| **Google Maps** | `AndroidManifest.xml` | [Google Cloud Console](https://console.cloud.google.com/) |
| **Google Sign-In** | Configured via `google-services.json` | Automatic with Firebase setup |
| **FCM (Push Notifications)** | Configured via Firebase | Automatic with Firebase setup |

---

## 📊 Project Structure & Dependencies

### Dependency Flowchart

```mermaid
graph TD
    A[main.dart] --> B[Firebase Core]
    A --> C[Provider]
    A --> D[App Theme]
    
    B --> E[Firebase Auth]
    B --> F[Cloud Firestore]
    B --> G[Firebase Storage]
    B --> H[Firebase Messaging]
    
    C --> I[AuthService]
    C --> J[FirestoreService]
    C --> K[ApiService]
    
    A --> L[Screens]
    L --> M[Home Screen]
    L --> N[SOS Alert Screen]
    L --> O[Contacts Screen]
    L --> P[Nearby Help Screen]
    L --> Q[Safety Map Screen]
    
    M --> R[Location Services]
    M --> S[Permission Handler]
    N --> T[Audio Players]
    N --> U[Local Notifications]
    O --> V[URL Launcher]
    P --> W[Geolocator]
    Q --> X[Flutter Map]
    Q --> Y[Google Maps]
```

### File Structure

```
lib/
├── main.dart                    # App entry point
├── screens/                     # UI Screens
│   ├── home_screen.dart         # Main dashboard
│   ├── login_screen.dart        # Google Sign-In
│   ├── sos_alert_screen.dart    # Emergency SOS
│   ├── contacts_screen.dart     # Emergency contacts
│   ├── nearby_help_screen.dart  # Find nearby help
│   ├── safety_map_screen.dart   # Location tracking
│   ├── geofence_screen.dart     # Safety zones
│   ├── chat_list_screen.dart    # Messaging
│   └── settings_screen.dart     # App settings
├── services/                    # Business logic
│   ├── auth_service.dart        # Authentication
│   ├── firestore_service.dart   # Database operations
│   ├── api_service.dart         # External APIs
│   ├── notification_service.dart # Push notifications
│   └── sms_service.dart         # SMS handling
├── widgets/                     # Reusable components
│   ├── add_place_dialog.dart
│   └── custom_button.dart
└── theme/                       # App styling
    └── app_theme.dart

android/
├── app/
│   ├── build.gradle             # Android build config
│   ├── google-services.json     # Firebase config (YOU NEED THIS!)
│   └── src/main/
│       └── AndroidManifest.xml  # Permissions & API keys

assets/
└── sounds/
    └── siren.mp3               # Emergency siren sound
```

### Key Dependencies

Based on `pubspec.yaml`, the app uses:

**Firebase Services:**
- `firebase_core: ^4.2.1` - Firebase initialization
- `firebase_auth: ^6.1.2` - User authentication
- `cloud_firestore: ^6.1.0` - NoSQL database
- `firebase_storage: ^13.0.4` - File storage
- `firebase_messaging: ^16.0.4` - Push notifications

**Location & Maps:**
- `geolocator: ^14.0.1` - GPS location
- `google_maps_flutter: ^2.5.0` - Google Maps
- `flutter_map: ^8.2.2` - Alternative mapping
- `latlong2: ^0.9.0` - Latitude/longitude utilities

**Communication:**
- `url_launcher: ^6.3.2` - Phone calls, SMS
- `permission_handler: ^12.0.1` - Runtime permissions

**Audio & Notifications:**
- `audioplayers: ^6.0.0` - Siren playback
- `flutter_local_notifications: ^19.5.0` - Local alerts
- `flutter_ringtone_player: ^4.0.0+3` - Ringtone player

**Authentication:**
- `google_sign_in: 6.2.1` - Google OAuth

**Utilities:**
- `provider: ^6.1.5` - State management
- `shared_preferences: ^2.5.3` - Local storage
- `intl: ^0.20.2` - Internationalization
- `crypto: ^3.0.3` - Blockchain ID generation

---

## 🏗️ Build & Run

### Run in Debug Mode

```bash
# Check for connected devices
flutter devices

# Run on connected Android device
flutter run

# Run on specific device
flutter run -d <device-id>
```

### Build Release APK

```bash
# Build release APK
flutter build apk --release

# Output location: build/app/outputs/flutter-apk/app-release.apk
```

### Install APK on Device

```bash
# Install the built APK
flutter install
```

Or manually transfer `build/app/outputs/flutter-apk/app-release.apk` to your device.

---

## 🔐 Permissions Required

The app requests the following Android permissions:

- ✅ **Location** (Fine, Coarse, Background) - For tracking and geofencing
- ✅ **Contacts** - To select emergency contacts
- ✅ **Phone & SMS** - To call and message contacts
- ✅ **Audio** - For voice recording
- ✅ **Storage** - For saving recordings and media
- ✅ **Notifications** - For emergency alerts
- ✅ **Internet** - For Firebase and API calls

All permissions are requested at runtime through the Settings screen.

---

## 🧪 Testing

### Run Automated Tests

```bash
flutter test
```

### Analyze Code Quality

```bash
flutter analyze
```

### Check for Outdated Dependencies

```bash
flutter pub outdated
```

---

## 🐛 Troubleshooting

### Common Issues & Solutions

#### 1. **Firebase Initialization Failed**

**Error:** `FirebaseException: [core/no-app]`

**Solution:**
- Ensure `google-services.json` is in `android/app/`
- Run `flutter clean` and `flutter pub get`
- Rebuild the app

#### 2. **Google Maps Not Showing**

**Error:** Blank map or error messages

**Solution:**
- Verify API key in `AndroidManifest.xml`
- Enable **Maps SDK for Android** in Google Cloud Console
- Check API key restrictions (should allow Android apps)

#### 3. **Permission Denied Errors**

**Error:** `PERMISSION_DENIED` in Firestore

**Solution:**
- Update Firestore rules from `firestore.rules` file
- Ensure user is authenticated before database operations

#### 4. **Siren Sound Not Playing**

**Error:** Audio file not found

**Solution:**
- Verify `assets/sounds/siren.mp3` exists
- Check `pubspec.yaml` has `assets: - assets/sounds/`
- Run `flutter pub get` after adding assets

#### 5. **Build Failures**

**Error:** Various Gradle or dependency errors

**Solution:**
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean
cd ..
flutter build apk
```

---

## 📈 Performance Optimization

- **Release Mode**: Always build in release mode for production
- **Code Obfuscation**: Use `--obfuscate` flag for security
- **Asset Optimization**: Compress images and audio files
- **Firebase Indexing**: Create composite indexes for complex queries

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👥 Authors

- **Vedant Mohite** - [@vedantmohite26](https://github.com/vedantmohite26)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Google Maps Platform for mapping services
- Open-source contributors

---

## 📞 Support

For issues and questions:
- Open an issue in the GitHub repository
- Check existing documentation in the `docs/` folder

---

## 🔄 Version History

- **v1.0.0** (2025-12-07) - Initial release
  - Core SOS alert functionality
  - Firebase integration
  - Location tracking
  - Emergency contacts
  - Safety zones
  - Push notifications

---

## 🚀 Deployment

### Google Play Store Deployment

1. Create a keystore for signing:
```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

2. Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=key
storeFile=<path-to-key.jks>
```

3. Build signed APK:
```bash
flutter build appbundle --release
```

4. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console

---

**⚠️ IMPORTANT NOTES:**

1. **Never commit API keys to public repositories**
2. **Replace the Google Maps API key with your own**
3. **Add your own `google-services.json` file**
4. **Update Firebase security rules for production**
5. **Test on real devices before releasing**

---

Made with ❤️ for Women's Safety
