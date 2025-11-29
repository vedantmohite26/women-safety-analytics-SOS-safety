import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get or create a chat between two users
  Future<String> getOrCreateChat(
    String userId1,
    String userId2,
    String userName1,
    String userName2,
  ) async {
    // Create a unique chat ID based on sorted user IDs
    final List<String> participants = [userId1, userId2]..sort();
    final String chatId = '${participants[0]}_${participants[1]}';

    try {
      final chatDoc = _db.collection('chats').doc(chatId);
      final chatSnapshot = await chatDoc.get();

      if (!chatSnapshot.exists) {
        // Create new chat
        await chatDoc.set({
          'participants': participants,
          'participantNames': {userId1: userName1, userId2: userName2},
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return chatId;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  /// Send a message in a chat
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      // Add message
      await _db.collection('chats').doc(chatId).collection('messages').add({
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'read': false,
      });

      // Update chat's last message
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages in a chat (only non-expired)
  Stream<QuerySnapshot> getMessages(String chatId) {
    final now = Timestamp.now();
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get all chats for a user
  Stream<QuerySnapshot> getChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId, String userId) async {
    try {
      final messages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Clean up expired messages (run periodically)
  Future<void> cleanupExpiredMessages() async {
    try {
      final now = Timestamp.now();
      final chats = await _db.collection('chats').get();

      for (var chatDoc in chats.docs) {
        final expiredMessages = await chatDoc.reference
            .collection('messages')
            .where('expiresAt', isLessThan: now)
            .get();

        final batch = _db.batch();
        for (var messageDoc in expiredMessages.docs) {
          batch.delete(messageDoc.reference);
        }

        if (expiredMessages.docs.isNotEmpty) {
          await batch.commit();
          debugPrint(
            'Cleaned up ${expiredMessages.docs.length} expired messages from ${chatDoc.id}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up expired messages: $e');
    }
  }

  // ==================== HUB CHAT METHODS ====================

  /// Send a message to the location-based hub
  Future<void> sendHubMessage({
    required String senderId,
    required String senderName,
    required double latitude,
    required double longitude,
    required String text,
  }) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      await _db.collection('hub_messages').add({
        'senderId': senderId,
        'senderName': senderName,
        'senderLocation': GeoPoint(latitude, longitude),
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      debugPrint('✅ Hub message sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending hub message: $e');
      rethrow;
    }
  }

  /// Get hub messages from users within a certain radius (in km)
  /// This fetches all non-expired messages and filters client-side by distance
  Stream<QuerySnapshot> getHubMessages() {
    final now = Timestamp.now();
    return _db
        .collection('hub_messages')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get count of nearby users in hub (within radius)
  Future<int> getNearbyHubUsers({
    required double userLat,
    required double userLon,
    required double radiusInKm,
  }) async {
    try {
      final now = DateTime.now();
      final recentTime = now.subtract(const Duration(minutes: 30));

      // Get recent hub messages
      final snapshot = await _db
          .collection('hub_messages')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(recentTime))
          .get();

      // Get unique users within radius
      final Set<String> nearbyUserIds = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderLocation = data['senderLocation'] as GeoPoint?;

        if (senderLocation != null) {
          final distance = _calculateDistance(
            userLat,
            userLon,
            senderLocation.latitude,
            senderLocation.longitude,
          );

          if (distance <= radiusInKm * 1000) {
            nearbyUserIds.add(data['senderId'] as String);
          }
        }
      }

      return nearbyUserIds.length;
    } catch (e) {
      debugPrint('Error getting nearby hub users: $e');
      return 0;
    }
  }

  /// Calculate distance between two coordinates in meters
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R * 1000; R = 6371 km
  }

  /// Clean up expired hub messages
  Future<void> cleanupExpiredHubMessages() async {
    try {
      final now = Timestamp.now();
      final expiredMessages = await _db
          .collection('hub_messages')
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _db.batch();
      for (var messageDoc in expiredMessages.docs) {
        batch.delete(messageDoc.reference);
      }

      if (expiredMessages.docs.isNotEmpty) {
        await batch.commit();
        debugPrint(
          '✅ Cleaned up ${expiredMessages.docs.length} expired hub messages',
        );
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up expired hub messages: $e');
    }
  }
}
