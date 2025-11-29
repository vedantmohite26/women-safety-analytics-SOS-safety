import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class NearbyHelpScreen extends StatefulWidget {
  const NearbyHelpScreen({super.key});

  @override
  State<NearbyHelpScreen> createState() => _NearbyHelpScreenState();
}

class _NearbyHelpScreenState extends State<NearbyHelpScreen> {
  Set<Marker> _markers = {};
  Position? _currentPosition;
  final double _radiusKm = 5.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });

      // Update user location in Firestore so they are visible to others
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );
        if (authService.userId != null) {
          await firestoreService.updateUserLocation(
            authService.userId!,
            position.latitude,
            position.longitude,
          );
        }
      }

      _loadNearbyUsers();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadNearbyUsers() async {
    if (_currentPosition == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.userId;

    // In a real app, you'd use GeoFlutterFire or similar for efficient querying.
    // For this demo, we'll fetch recent active users and filter client-side.
    // This is NOT scalable for production but works for a demo.

    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('lastLocationUpdate', isGreaterThan: oneHourAgo)
          .get();

      final newMarkers = <Marker>{};

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue; // Skip self

        final data = doc.data();

        // Check visibility
        if (data['isVisible'] == false) continue;

        double? lat;
        double? lng;

        // Handle GeoPoint (preferred)
        if (data['lastLocation'] is GeoPoint) {
          final geoPoint = data['lastLocation'] as GeoPoint;
          lat = geoPoint.latitude;
          lng = geoPoint.longitude;
        }
        // Fallback to separate fields (legacy support)
        else if (data['latitude'] != null && data['longitude'] != null) {
          lat = (data['latitude'] as num).toDouble();
          lng = (data['longitude'] as num).toDouble();
        }

        final name = data['displayName'] as String? ?? 'User';

        if (lat != null && lng != null) {
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lng,
          );

          if (distance <= _radiusKm * 1000) {
            newMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: '${(distance / 1000).toStringAsFixed(1)} km away',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueCyan,
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby users: $e');
    }
  }

  Future<void> _requestHelp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId == null || _currentPosition == null) return;

    try {
      // 1. Send notifications to all nearby users found on map
      final nearbyUserIds = _markers.map((m) => m.markerId.value).toList();

      if (nearbyUserIds.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No nearby users found to notify.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show sending indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sending help request to nearby users...'),
          duration: Duration(seconds: 1),
        ),
      );

      final username = authService.username ?? 'Someone';

      // Send notifications in parallel
      await Future.wait(
        nearbyUserIds.map(
          (userId) => firestoreService.sendNotification(
            toUserId: userId,
            title: 'HELP NEEDED!',
            body: '$username needs help nearby!',
            data: {
              'type': 'nearby_help_request',
              'requesterId': authService.userId,
              'requesterName': username,
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
              'timestamp': DateTime.now().toIso8601String(),
            },
          ),
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Help request sent to ${nearbyUserIds.length} nearby users!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // 2. Also create an SOS alert
      await firestoreService.addSOSAlert(
        userId: authService.userId!,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Help'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (_currentPosition != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 14.0,
              ),
              markers: {
                ..._markers,
                Marker(
                  markerId: const MarkerId('me'),
                  position: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                  infoWindow: const InfoWindow(title: 'Me'),
                ),
              },
              circles: {
                Circle(
                  circleId: const CircleId('radius'),
                  center: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  radius: _radiusKm * 1000,
                  fillColor: Colors.blue.withValues(alpha: 0.1),
                  strokeColor: Colors.blue.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Bottom Action Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nearby Active Users: ${_markers.length}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users within ${_radiusKm.toInt()}km radius',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _requestHelp,
                    icon: const Icon(Icons.campaign_rounded),
                    label: const Text('REQUEST HELP FROM NEARBY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
