import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/sms_service.dart';
import '../services/siren_service.dart';

class SOSAlertScreen extends StatefulWidget {
  const SOSAlertScreen({super.key});

  @override
  State<SOSAlertScreen> createState() => _SOSAlertScreenState();
}

class _SOSAlertScreenState extends State<SOSAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final SirenService _sirenService = SirenService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SMSService _smsService = SMSService();

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Timer? _timer;
  int _secondsActive = 0;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _getCurrentLocation();
    _startTimer();
    _startSOS();
  }

  Future<void> _startSOS() async {
    // 1. Play Siren (Background) - Immediate feedback
    await _sirenService.startSiren();

    // 2. Send Alerts (Location Share) - PRIORITY 1
    // We do this BEFORE dialing to ensure location is sent even if the call takes over UI
    await _sendAlerts();

    // 3. Auto-dial 100 (Emergency) - PRIORITY 2
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: '100');
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint('Error dialing emergency number: $e');
    }

    // 4. Show Notification
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initSettings);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'sos_channel',
          'SOS Alerts',
          channelDescription: 'Active SOS alert',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          color: Colors.red,
          enableVibration: true,
        );
    const NotificationDetails notifDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      0,
      'SOS EMERGENCY ACTIVATED',
      'Siren playing. Help alerted.',
      notifDetails,
    );
  }

  Future<void> _sendAlerts() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (authService.userId != null) {
        // 1. Create SOS Alert in Firestore
        await firestoreService.addSOSAlert(
          userId: authService.userId!,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        // 2. Send SMS to Contacts
        await _smsService.sendSOSAlert(
          userId: authService.userId!,
          latitude: position.latitude,
          longitude: position.longitude,
          userName: authService.currentUser?.displayName,
        );

        // 3. Notify Nearby Users (5km Radius)
        final nearbyUserIds = await firestoreService.getNearbyUsers(
          authService.userId!,
          position.latitude,
          position.longitude,
          5.0, // 5km radius
        );

        debugPrint('Found ${nearbyUserIds.length} nearby users');

        for (final nearbyUserId in nearbyUserIds) {
          await firestoreService.sendNotification(
            toUserId: nearbyUserId,
            title: 'SOS ALERT NEARBY!',
            body: 'Someone near you needs help! Tap to view location.',
            data: {
              'type': 'sos_alert',
              'lat': position.latitude,
              'lng': position.longitude,
              'senderId': authService.userId,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending SOS alert: $e');
    }
  }

  Future<void> _stopSOS() async {
    await _sirenService.stopSiren();
    await _notificationsPlugin.cancel(0);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsActive++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    // Do NOT stop siren here. It must be stopped manually via _stopSOS button.
    // _sirenService.stopSiren();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Maps Background
          GoogleMap(
            initialCameraPosition: _currentLocation != null
                ? CameraPosition(target: _currentLocation!, zoom: 15.0)
                : _defaultPosition,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _currentLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('current_location'),
                      position: _currentLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                      infoWindow: const InfoWindow(
                        title: 'Your Location',
                        snippet: 'SOS Alert Active',
                      ),
                    ),
                  }
                : {},
          ),

          // Top Status Bar
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white.withValues(
                              alpha: 0.5 + (_pulseController.value * 0.5),
                            ),
                            size: 32,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SOS ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Duration: ${_formatDuration(_secondsActive)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusIndicator(
                        icon: Icons.location_on,
                        label: 'Location Shared',
                        isActive: _currentLocation != null,
                      ),
                      // Removed Recording Indicator
                      _buildStatusIndicator(
                        icon: Icons.phone_in_talk,
                        label: 'Dialing 100',
                        isActive: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Stop Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _stopSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop_circle, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'STOP SOS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      children: [
        Icon(icon, color: isActive ? Colors.white : Colors.white38, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
