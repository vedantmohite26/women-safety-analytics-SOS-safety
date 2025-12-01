import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_scaffold.dart';
import 'contacts_screen.dart';
import 'user_info_screen.dart';

import 'fake_call_screen.dart';
import 'permissions_screen.dart';
import 'settings_screen.dart';

import 'safety_map_screen.dart';
import 'sos_alert_screen.dart';
import 'nearby_help_screen.dart';
import 'chat_list_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../widgets/audio_recorder_button.dart';
import 'package:share_plus/share_plus.dart';

// Top-level function for background FCM messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _serverStatus = 'Checking...';
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _sessionSubscription;
  Timer? _locationTimer;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _currentZones =
      {}; // Track which zones user is currently in

  @override
  void initState() {
    super.initState();
    _checkServer();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initSession();
    if (mounted) {
      _checkPermissions();
      _setupNotifications();
      _setupFCM();
      _startLocationUpdates();
      _monitorSession();
    }
  }

  /// Initialize session on app start
  Future<void> _initSession() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.initSession();
    await authService.ensureUserInitialized();
  }

  /// Monitor session to detect multi-device login
  void _monitorSession() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId != null && authService.sessionId != null) {
      _sessionSubscription = firestoreService
          .listenToUserDoc(authService.userId!)
          .listen((snapshot) {
            if (!snapshot.exists || !mounted) return;

            final data = snapshot.data() as Map<String, dynamic>?;
            final firestoreSessionId = data?['sessionId'] as String?;

            // If session ID changed, another device logged in
            if (firestoreSessionId != null &&
                firestoreSessionId != authService.sessionId) {
              debugPrint('Session mismatch detected. Logging out...');

              // Show notification
              _showNotification(
                'Account Security',
                'You have been signed in on another device.',
              );

              // Sign out
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  authService.signOut();
                }
              });
            }
          });
    }
  }

  Future<void> _checkServer() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final result = await api.checkStatus();
      if (!mounted) return;
      setState(() {
        _serverStatus = result['status'] == 'online' ? 'Online' : 'Offline';
      });

      // Check for default zones
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      if (authService.userId != null) {
        await firestoreService.checkAndCreateDefaultZones(authService.userId!);
        _checkPhoneNumber();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _serverStatus = 'Offline');
    }
  }

  Future<void> _checkPhoneNumber() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId != null) {
      final phone = await firestoreService.getContactPhoneNumber(
        authService.userId!,
      );
      if (phone == null || phone.isEmpty) {
        if (!mounted) return;
        _showPhoneDialog();
      }
    }
  }

  Future<void> _showPhoneDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Contact Number Required'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please enter your contact number to continue. This is crucial for your safety.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91XXXXXXXXXX',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a phone number';
                    }
                    if (!RegExp(r'^\+[1-9]\d{9,14}$').hasMatch(value)) {
                      return 'Format: +CountryCodeNumber';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  final firestoreService = Provider.of<FirestoreService>(
                    context,
                    listen: false,
                  );

                  try {
                    await firestoreService.updateContactPhoneNumber(
                      authService.userId!,
                      controller.text.trim(),
                      verified: false,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone number saved!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setupFCM() async {
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_alerts',
      'Emergency Alerts',
      description: 'High priority notifications for emergency help requests',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('siren'),
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Request permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Foreground message received: ${message.messageId}');

      // Check if it's a help request
      if (message.data['type'] == 'nearby_help_request' ||
          message.data['type'] == 'help_request') {
        // Play siren sound
        try {
          await _audioPlayer.stop();
          await _audioPlayer.play(AssetSource('sounds/siren.mp3'));
          debugPrint('🔊 Siren playing for emergency alert');
        } catch (e) {
          debugPrint('Error playing siren: $e');
        }

        // Show notification
        if (mounted) {
          _showNotification(
            message.notification?.title ?? 'EMERGENCY HELP NEEDED!',
            message.notification?.body ?? 'Someone nearby needs help',
          );
        }
      }
    });

    debugPrint('✅ FCM setup complete');
  }

  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initSettings);

    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId != null) {
      _notificationSubscription = firestoreService
          .listenForNotifications(authService.userId!)
          .listen((snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data() as Map<String, dynamic>;
                _showNotification(
                  data['title'] ?? 'Alert',
                  data['body'] ?? 'New notification',
                );
                // Mark as read immediately for this demo
                firestoreService.markNotificationAsRead(
                  authService.userId!,
                  change.doc.id,
                );
              }
            }
          });
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'nearby_help_channel',
          'Nearby Help Alerts',
          channelDescription: 'Alerts for nearby SOS requests',
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.red,
        );
    const NotificationDetails notifDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      notifDetails,
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.red)),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _startLocationUpdates() {
    // Update location every 5 minutes
    _locationTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (authService.userId != null) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          await firestoreService.updateUserLocation(
            authService.userId!,
            position.latitude,
            position.longitude,
          );

          // Check for zone entry
          await _checkZoneEntry(position, firestoreService);
        } catch (e) {
          debugPrint('Error updating location: $e');
        }
      }
    });
  }

  /// Check if user entered any zones and send notifications
  Future<void> _checkZoneEntry(
    Position position,
    FirestoreService firestoreService,
  ) async {
    try {
      final snapshot = await firestoreService.getAllZones().first;
      final Set<String> enteredZones = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final zoneId = data['id'] as String?;
        final zoneName = data['name'] as String?;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final radius = (data['radius'] as num?)?.toDouble();
        final type = data['type'] as String?;

        if (zoneId == null || lat == null || lng == null || radius == null) {
          continue;
        }

        // Calculate distance to zone center
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        // Check if user is within zone
        if (distance <= radius) {
          enteredZones.add(zoneId);

          // Send notification if newly entered
          if (!_currentZones.contains(zoneId) && mounted) {
            String title = 'Zone Alert';
            String body = 'You entered a zone';

            // Get the actual zone name if available
            final displayName = zoneName ?? 'Unknown Zone';

            if (type?.contains('safe') == true) {
              title = 'Safe Zone';
              body = 'You have entered: $displayName';
            } else if (type?.contains('danger') == true) {
              title = 'Danger Zone!';
              body = 'Warning: You entered $displayName';
            } else if (type?.contains('accident') == true) {
              title = 'Accident Zone';
              body = 'Caution: You entered $displayName';
            } else {
              body = 'You entered: $displayName';
            }

            _showNotification(title, body);
          }
        }
      }

      // Update current zones
      if (mounted) {
        setState(() {
          _currentZones.clear();
          _currentZones.addAll(enteredZones);
        });
      }
    } catch (e) {
      debugPrint('Error checking zones: $e');
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _sessionSubscription?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;

    // Check storage/media permissions
    bool storageGranted = false;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final photos = await Permission.photos.status;
        final videos = await Permission.videos.status;
        final audio = await Permission.audio.status;
        storageGranted =
            photos.isGranted || videos.isGranted || audio.isGranted;
      } else {
        final storage = await Permission.storage.status;
        storageGranted = storage.isGranted;
      }
    } else {
      // iOS etc
      storageGranted = await Permission.storage.isGranted;
    }

    // We can decide if storage is mandatory. For now, let's keep it as:
    // If location or notification is missing, OR if storage is missing (optional but recommended),
    // we show the screen. But usually we only force critical ones.
    // Let's stick to forcing Location & Notification as critical,
    // but if the user hasn't granted storage yet, we might want to prompt them?
    // The user asked to "ask for storage permission", so we should probably include it in the check.

    if (!locationStatus.isGranted ||
        !notificationStatus.isGranted ||
        !storageGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PermissionsScreen(
            onPermissionsGranted: () {
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
  }

  Future<void> _shareLiveLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final url =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      await SharePlus.instance.share(
        ShareParams(text: 'Tracking my live location: $url'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share location: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Safety Guardian'),
        actions: [
          _buildServerStatusChip(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildSafetyStatusCard(theme),
              const SizedBox(height: 24),
              _buildSOSButton(theme),
              const SizedBox(height: 24),

              // New Action Row: Live Location & Audio Recording
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareLiveLocation,
                      icon: const Icon(Icons.share_location),
                      label: const Text('Share Live Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  AudioRecorderButton(
                    onRecordingComplete: (path) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Audio saved to: $path')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildFeatureCard(
                      context,
                      'Safety Map',
                      Icons.map_rounded,
                      Colors.blue,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SafetyMapScreen(),
                        ),
                      ),
                    ),
                    _buildFeatureCard(
                      context,
                      'Contacts',
                      Icons.contacts_rounded,
                      Colors.orange,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactsScreen(),
                        ),
                      ),
                    ),
                    _buildFeatureCard(
                      context,
                      'Nearby Help',
                      Icons.near_me_rounded,
                      AppTheme.secondary,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NearbyHelpScreen(),
                        ),
                      ),
                    ),
                    _buildFeatureCard(
                      context,
                      'Live Chat',
                      Icons.chat,
                      Colors.purple,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        ),
                      ),
                    ),
                    _buildFeatureCard(
                      context,
                      'Fake Call',
                      Icons.call,
                      Colors.teal,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FakeCallScreen(),
                        ),
                      ),
                    ),
                    _buildFeatureCard(
                      context,
                      'Profile',
                      Icons.person,
                      Colors.indigo,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserInfoScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatusChip() {
    final isOnline = _serverStatus == 'Online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? AppTheme.success.withValues(alpha: 0.5)
              : AppTheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: isOnline ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(width: 6),
          Text(
            _serverStatus,
            style: TextStyle(
              color: isOnline ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyStatusCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration.copyWith(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are Safe',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'No threats detected nearby',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(ThemeData theme) {
    return SizedBox(
      height: 72,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SOSAlertScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.warning_amber_rounded, size: 32),
            SizedBox(width: 12),
            Text(
              'SOS EMERGENCY',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
