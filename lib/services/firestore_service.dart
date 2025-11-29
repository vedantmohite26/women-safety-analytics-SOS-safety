import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> writeDiagnostic(String docId, Map<String, dynamic> data) async {
    await _db.collection('diagnostics').doc(docId).set(data);
  }

  Future<DocumentSnapshot> readDiagnostic(String docId) async {
    return await _db.collection('diagnostics').doc(docId).get();
  }

  Future<void> addSOSAlert({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    await _db.collection('sos_alerts').add({
      'userId': userId,
      'location': GeoPoint(latitude, longitude),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  /// Save user data including blockchain ID and session ID
  Future<void> saveUserData({
    required String userId,
    required String blockchainId,
    String? sessionId,
    String? fcmToken,
    String? displayName,
    String? email,
    String? photoURL,
    String? phoneNumber,
    bool phoneVerified = false,
    String? contactPhoneNumber,
    bool contactPhoneVerified = false,
  }) async {
    debugPrint('🔷 FirestoreService: Saving user data for userId: $userId');
    debugPrint('🔷 BlockchainID: $blockchainId');
    debugPrint('🔷 SessionID: $sessionId');
    debugPrint('🔷 DisplayName: $displayName');
    debugPrint('🔷 Email: $email');

    final data = <String, dynamic>{
      'blockchainId': blockchainId,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'phoneVerified': phoneVerified,
      'lastSignIn': FieldValue.serverTimestamp(),
    };

    // Add session ID if provided (for single device login enforcement)
    if (sessionId != null) {
      data['sessionId'] = sessionId;
    }

    // Add FCM token if provided (for push notifications)
    if (fcmToken != null) {
      data['fcmToken'] = fcmToken;
      debugPrint('🔵 FCM Token saved to Firestore');
    }

    // Add contact phone number if provided
    if (contactPhoneNumber != null) {
      data['contactPhoneNumber'] = contactPhoneNumber;
      data['contactPhoneVerified'] = contactPhoneVerified;
      if (contactPhoneVerified) {
        data['contactPhoneVerifiedAt'] = FieldValue.serverTimestamp();
      }
    }

    // Only add verifiedAt if phone is verified
    if (phoneVerified) {
      data['verifiedAt'] = FieldValue.serverTimestamp();
    }

    final docRef = _db.collection('users').doc(userId);
    final docSnapshot = await docRef.get();

    // Generate username if it doesn't exist
    if (!docSnapshot.exists || docSnapshot.data()?['username'] == null) {
      data['createdAt'] = FieldValue.serverTimestamp();

      String baseName = 'user';
      if (displayName != null && displayName.isNotEmpty) {
        baseName = displayName.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
      } else if (email != null && email.isNotEmpty) {
        baseName = email
            .split('@')[0]
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
      }

      // Append random number (1 to 100000)
      final random = Random();
      final suffix = random.nextInt(100000) + 1;
      final username = '$baseName$suffix';
      data['username'] = username;

      debugPrint('✅ Generated new username: $username');
    } else {
      debugPrint(
        'ℹ️ Username already exists: ${docSnapshot.data()?['username']}',
      );
    }

    await docRef.set(data, SetOptions(merge: true));
    debugPrint('✅ User data saved successfully to Firestore');
  }

  /// Get current session ID for user
  Future<String?> getSessionId(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['sessionId'] as String?;
  }

  /// Listen to user document for session changes
  Stream<DocumentSnapshot> listenToUserDoc(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  /// Get blockchain ID for user
  Future<String?> getBlockchainId(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final blockchainId = doc.data()?['blockchainId'] as String?;
      debugPrint('📖 Fetched blockchain ID: $blockchainId');
      return blockchainId;
    } catch (e) {
      debugPrint('❌ Error fetching blockchain ID: $e');
      return null;
    }
  }

  /// Get username for user
  Future<String?> getUsername(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final username = doc.data()?['username'] as String?;
      debugPrint('📖 Fetched username: $username');
      return username;
    } catch (e) {
      debugPrint('❌ Error fetching username: $e');
      return null;
    }
  }

  /// Get contact phone number for user
  Future<String?> getContactPhoneNumber(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final phone = doc.data()?['contactPhoneNumber'] as String?;
      debugPrint('📖 Fetched contact phone: $phone');
      return phone;
    } catch (e) {
      debugPrint('❌ Error fetching contact phone: $e');
      return null;
    }
  }

  /// Update contact phone number
  Future<void> updateContactPhoneNumber(
    String userId,
    String phoneNumber, {
    required bool verified,
  }) async {
    final data = <String, dynamic>{
      'contactPhoneNumber': phoneNumber,
      'contactPhoneVerified': verified,
    };

    if (verified) {
      data['contactPhoneVerifiedAt'] = FieldValue.serverTimestamp();
    }

    await _db.collection('users').doc(userId).update(data);
    debugPrint('✅ Contact phone number updated');
  }

  // Emergency Contacts Management
  Future<void> addEmergencyContact(
    String userId,
    String name,
    String phone,
  ) async {
    await _db.collection('users').doc(userId).collection('contacts').add({
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getEmergencyContacts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteEmergencyContact(String userId, String contactId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  // Zone Management
  Future<void> checkAndCreateDefaultZones(String userId) async {
    try {
      final zonesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('zones')
          .get();

      if (zonesSnapshot.docs.isEmpty) {
        // Create default "Home" zone
        try {
          final position = await Geolocator.getCurrentPosition();
          final zoneId = DateTime.now().millisecondsSinceEpoch.toString();
          await addZone(userId, {
            'id': zoneId,
            'name': 'Home',
            'latitude': position.latitude,
            'longitude': position.longitude,
            'radius': 500.0,
          });
          debugPrint('Default Home zone created.');
        } catch (e) {
          debugPrint('Could not get location for default zone: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking default zones: $e');
    }
  }

  Future<void> addZone(String userId, Map<String, dynamic> zoneData) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('zones')
        .doc(zoneData['id'])
        .set(zoneData);
  }

  Stream<QuerySnapshot> getZones(String userId) {
    return _db.collection('users').doc(userId).collection('zones').snapshots();
  }

  /// Get ALL zones from ALL users (Global Visibility)
  Stream<QuerySnapshot> getAllZones() {
    debugPrint('🗺️ Fetching ALL zones using collectionGroup...');
    try {
      return _db.collectionGroup('zones').snapshots().handleError((error) {
        debugPrint('❌ Error fetching zones: $error');
      });
    } catch (e) {
      debugPrint('❌ Exception in getAllZones: $e');
      rethrow;
    }
  }

  Future<void> deleteZone(String userId, String zoneId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('zones')
        .doc(zoneId)
        .delete();
  }

  Future<void> clearZones(String userId) async {
    final batch = _db.batch();
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('zones')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Safety Places Management (Public/Crowdsourced)
  Future<String> addSafetyPlace({
    required String userId,
    required String userName,
    required String name,
    required String category, // hospital, police, fire_brigade
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    final docRef = await _db.collection('safety_places').add({
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'addedBy': userId,
      'addedByName': userName,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Stream<QuerySnapshot> getSafetyPlaces() {
    return _db
        .collection('safety_places')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getSafetyPlacesByCategory(String category) {
    return _db
        .collection('safety_places')
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateSafetyPlace({
    required String placeId,
    required String userId,
    String? name,
    String? description,
    String? category,
  }) async {
    final doc = await _db.collection('safety_places').doc(placeId).get();
    if (doc.exists && doc.data()?['addedBy'] == userId) {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;

      if (updates.isNotEmpty) {
        await _db.collection('safety_places').doc(placeId).update(updates);
      }
    } else {
      throw Exception('Unauthorized to update this place');
    }
  }

  Future<void> deleteSafetyPlace(String placeId, String userId) async {
    final doc = await _db.collection('safety_places').doc(placeId).get();
    if (doc.exists && doc.data()?['addedBy'] == userId) {
      await _db.collection('safety_places').doc(placeId).delete();
    } else {
      throw Exception('Unauthorized to delete this place');
    }
  }

  // Location & Notification Services
  Future<void> updateUserLocation(
    String userId,
    double latitude,
    double longitude, {
    bool isVisible = true,
  }) async {
    await _db.collection('users').doc(userId).set({
      'lastLocation': GeoPoint(latitude, longitude),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'isVisible': isVisible,
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getNearbyUsersDetails(
    String currentUserId,
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    final snapshot = await _db
        .collection('users')
        .where('lastLocationUpdate', isGreaterThan: yesterday)
        .get();

    final List<Map<String, dynamic>> nearbyUsers = [];

    for (var doc in snapshot.docs) {
      if (doc.id == currentUserId) continue;

      final data = doc.data();
      // Check visibility (default to true if missing)
      if (data['isVisible'] == false) continue;

      if (data.containsKey('lastLocation')) {
        final GeoPoint loc = data['lastLocation'];
        final double distanceInMeters = _calculateDistance(
          latitude,
          longitude,
          loc.latitude,
          loc.longitude,
        );

        if (distanceInMeters <= (radiusInKm * 1000)) {
          nearbyUsers.add({
            'userId': doc.id,
            'distance': distanceInMeters,
            'lastActive': data['lastLocationUpdate'],
            'displayName': data['displayName'] ?? 'Unknown User',
          });
        }
      }
    }
    // Sort by distance
    nearbyUsers.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );
    return nearbyUsers;
  }

  Future<List<String>> getNearbyUsers(
    String currentUserId,
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    // Note: For a production app, use GeoFlutterFire or a proper geo-query solution.
    // This is a simple client-side filter for demonstration.
    // We fetch users active in the last 24 hours to reduce read costs/latency.
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    final snapshot = await _db
        .collection('users')
        .where('lastLocationUpdate', isGreaterThan: yesterday)
        .get();

    final List<String> nearbyUserIds = [];

    for (var doc in snapshot.docs) {
      if (doc.id == currentUserId) continue; // Skip self

      final data = doc.data();
      // Check visibility
      if (data['isVisible'] == false) continue;

      if (data.containsKey('lastLocation')) {
        final GeoPoint loc = data['lastLocation'];
        final double distanceInMeters = _calculateDistance(
          latitude,
          longitude,
          loc.latitude,
          loc.longitude,
        );

        if (distanceInMeters <= (radiusInKm * 1000)) {
          nearbyUserIds.add(doc.id);
        }
      }
    }
    return nearbyUserIds;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Returns meters
  }

  Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection('users')
        .doc(toUserId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'data': data,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot> listenForNotifications(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(
    String userId,
    String notificationId,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}
