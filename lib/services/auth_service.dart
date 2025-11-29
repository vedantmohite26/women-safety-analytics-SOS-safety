import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String? _blockchainId;
  String? _sessionId;
  String? _username;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Generate a unique session ID for single device login
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return '$timestamp-$random';
  }

  /// Initialize or load session ID
  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('session_id');
    debugPrint('✅ Session loaded/initialized: $_sessionId');
  }

  /// Sign in with Google and generate blockchain ID and session ID
  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google Sign-In...');

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ User canceled sign-in');
        return null; // User canceled sign-in
      }

      debugPrint('✅ Google account selected: ${googleUser.email}');

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      debugPrint('✅ Firebase authentication successful');

      // Generate session ID and handle blockchain ID
      if (userCredential.user != null) {
        final firestoreService = FirestoreService();

        // Check if blockchain ID already exists
        final existingBlockchainId = await firestoreService.getBlockchainId(
          userCredential.user!.uid,
        );

        if (existingBlockchainId != null) {
          _blockchainId = existingBlockchainId;
          debugPrint('✅ Existing Blockchain ID loaded: $_blockchainId');
        } else {
          _blockchainId = _generateBlockchainId(userCredential.user!.uid);
          debugPrint('✅ New Blockchain ID generated: $_blockchainId');
        }

        // Fetch username
        _username = await firestoreService.getUsername(
          userCredential.user!.uid,
        );
        debugPrint('✅ Username loaded: $_username');

        // Generate new session ID (Always new for single device login)
        _sessionId = _generateSessionId();
        debugPrint('✅ New Session ID generated: $_sessionId');

        // Store session ID locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_id', _sessionId!);

        debugPrint('✅ Session ID stored in SharedPreferences');

        // Get FCM token for push notifications
        String? fcmToken;
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
          debugPrint('✅ FCM Token: $fcmToken');
        } catch (e) {
          debugPrint('⚠️ Error getting FCM token: $e');
        }

        // Save user data to Firestore
        await firestoreService.saveUserData(
          userId: userCredential.user!.uid,
          blockchainId: _blockchainId!,
          sessionId: _sessionId,
          fcmToken: fcmToken,
          displayName: userCredential.user!.displayName,
          email: userCredential.user!.email,
          photoURL: userCredential.user!.photoURL,
          phoneNumber: userCredential.user!.phoneNumber,
          phoneVerified: userCredential.user!.phoneNumber != null,
        );

        // If username was null (new user), fetch it again after saveUserData generated it
        if (_username == null) {
          _username = await firestoreService.getUsername(
            userCredential.user!.uid,
          );
          debugPrint('✅ Username generated and loaded: $_username');
        }
      }

      return userCredential.user;
    } catch (e) {
      debugPrint('❌ Error signing in with Google: $e');
      return null;
    }
  }

  /// Generate a blockchain-like hash using SHA-256
  String _generateBlockchainId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$userId:$timestamp';
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.disconnect();
      await _googleSignIn.signOut();
    } catch (_) {}

    // Clear session ID on sign out
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');

    _blockchainId = null;
    _sessionId = null;
    _username = null;
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  /// Ensure user data is initialized in Firestore (for existing sessions)
  Future<void> ensureUserInitialized() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final firestoreService = FirestoreService();

      // Check if blockchain ID exists in Firestore
      final existingBlockchainId = await firestoreService.getBlockchainId(
        user.uid,
      );

      // Always try to load username
      _username = await firestoreService.getUsername(user.uid);

      if (existingBlockchainId == null) {
        debugPrint('⚠️ Blockchain ID missing for existing user. Generating...');

        // Generate new IDs
        _blockchainId = _generateBlockchainId(user.uid);
        _sessionId ??= _generateSessionId(); // Use existing or generate new

        // Save to Firestore
        await firestoreService.saveUserData(
          userId: user.uid,
          blockchainId: _blockchainId!,
          sessionId: _sessionId,
          displayName: user.displayName,
          email: user.email,
          photoURL: user.photoURL,
          phoneNumber: user.phoneNumber,
          phoneVerified: user.phoneNumber != null,
        );

        // If username was null, fetch it again after saveUserData generated it
        _username ??= await firestoreService.getUsername(user.uid);

        debugPrint('✅ User data initialized and saved.');
      } else {
        _blockchainId = existingBlockchainId;
        debugPrint('✅ Blockchain ID loaded: $_blockchainId');
        debugPrint('✅ Username loaded: $_username');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring user initialized: $e');
    }
  }

  // Convenience getters used by UI
  String? get userDisplayName => _auth.currentUser?.displayName;
  String? get userEmail => _auth.currentUser?.email;
  String? get userPhotoURL => _auth.currentUser?.photoURL;
  String? get userId => _auth.currentUser?.uid;
  String? get blockchainId => _blockchainId;
  String? get sessionId => _sessionId;
  String? get username => _username;
  User? get currentUser => _auth.currentUser;
}
