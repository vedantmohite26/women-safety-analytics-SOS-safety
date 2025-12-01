import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class SMSService {
  Future<List<String>> getEmergencyContactNumbers(String userId) async {
    try {
      final contactsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          // Removed incorrect filter: .where('isEmergency', isEqualTo: true)
          .get();

      return contactsSnapshot.docs
          .map((doc) => doc.data()['phone'] as String?)
          .where((phone) => phone != null && phone.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching emergency contacts: $e');
      return [];
    }
  }

  Future<void> sendSOSAlert({
    required String userId,
    required double latitude,
    required double longitude,
    String? userName,
  }) async {
    try {
      final recipients = await getEmergencyContactNumbers(userId);
      final locationLink = 'https://maps.google.com/?q=$latitude,$longitude';
      final message =
          '🚨 SOS ALERT 🚨\n'
          '${userName ?? 'User'} needs help!\n'
          'Location: $locationLink';

      if (recipients.isNotEmpty) {
        // Try to open SMS app with pre-filled numbers
        final separator = Platform.isAndroid ? ';' : '&';
        final phones = recipients.join(separator);
        final uri = Uri(
          scheme: 'sms',
          path: phones,
          queryParameters: {'body': message},
        );

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          debugPrint('Launched SMS to ${recipients.length} contacts');
          return;
        }
      }

      // Fallback to Share sheet if no contacts or SMS launch fails
      debugPrint('Falling back to Share sheet');
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (e) {
      debugPrint('Error sharing SOS alert: $e');
    }
  }
}
