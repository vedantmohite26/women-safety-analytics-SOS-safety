import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_scaffold.dart';
import '../widgets/add_place_dialog.dart';
import '../widgets/add_zone_dialog.dart';

enum ZoneType { safe, danger, accident }

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(28.6139, 77.2090);

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  String _selectedFilter = 'All Places';
  List<Map<String, dynamic>> _places = [];

  // Stream subscriptions
  StreamSubscription? _zonesSubscription;
  StreamSubscription? _placesSubscription;

  // Cached marker icons
  BitmapDescriptor? _policeIcon;
  BitmapDescriptor? _hospitalIcon;
  BitmapDescriptor? _safetyIcon;
  BitmapDescriptor? _safeZoneIcon;
  BitmapDescriptor? _redZoneIcon;
  BitmapDescriptor? _accidentZoneIcon;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _getCurrentLocation();
    _loadZones();
    _loadSafetyPlaces();
  }

  @override
  void dispose() {
    _zonesSubscription?.cancel();
    _placesSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _loadMarkerIcons() {
    _policeIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueBlue,
    );
    _hospitalIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    );
    _safetyIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );

    _safeZoneIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueGreen,
    );
    _redZoneIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    );
    _accidentZoneIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _loadZones() {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _zonesSubscription?.cancel();
    _zonesSubscription = firestoreService.getAllZones().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _circles.removeWhere((c) => c.circleId.value.startsWith('zone_'));
        _markers.removeWhere((m) => m.markerId.value.startsWith('zone_'));
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final zoneId = data['id'];
          final location = LatLng(data['latitude'], data['longitude']);
          final radius = (data['radius'] as num).toDouble();
          final type = ZoneType.values.firstWhere(
            (e) => e.toString() == data['type'],
            orElse: () => ZoneType.safe,
          );
          _circles.add(
            Circle(
              circleId: CircleId('zone_$zoneId'),
              center: location,
              radius: radius,
              fillColor: _getZoneColor(type).withValues(alpha: 0.3),
              strokeColor: _getZoneColor(type),
              strokeWidth: 2,
            ),
          );
          _markers.add(
            Marker(
              markerId: MarkerId('zone_$zoneId'),
              position: location,
              icon: _getMarkerIcon(type),
              infoWindow: InfoWindow(
                title: _getZoneName(type),
                snippet: '${radius.toInt()}m radius',
              ),
              onTap: () => _showZoneOptions(zoneId, type, radius),
            ),
          );
        }
      });
    });
  }

  void _loadSafetyPlaces() {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _placesSubscription?.cancel();
    _placesSubscription = firestoreService.getSafetyPlaces().listen((snapshot) {
      if (!mounted) return;
      final places = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'category': data['category'] ?? 'police',
          'lat': (data['latitude'] ?? 0.0) as double,
          'lng': (data['longitude'] ?? 0.0) as double,
          'description': data['description'] ?? '',
          'addedBy': data['addedBy'] ?? '',
          'userName': data['addedByName'] ?? 'Unknown',
        };
      }).toList();
      setState(() {
        _places = places;
        _updatePlaceMarkers();
      });
    });
  }

  void _updatePlaceMarkers() {
    // Remove existing place markers
    _markers.removeWhere((m) => m.markerId.value.startsWith('place_'));
    // Add markers for filtered places
    for (var place in _filteredPlaces) {
      BitmapDescriptor icon;
      if (place['category'] == 'police') {
        icon = _policeIcon ?? BitmapDescriptor.defaultMarker;
      } else if (place['category'] == 'hospital') {
        icon = _hospitalIcon ?? BitmapDescriptor.defaultMarker;
      } else if (place['category'] == 'fire_brigade') {
        icon =
            _accidentZoneIcon ??
            BitmapDescriptor.defaultMarker; // Reusing orange icon
      } else {
        icon = _safetyIcon ?? BitmapDescriptor.defaultMarker;
      }

      _markers.add(
        Marker(
          markerId: MarkerId('place_${place['id']}'),
          position: LatLng(place['lat'], place['lng']),
          icon: icon,
          infoWindow: InfoWindow(
            title: place['name'],
            snippet: place['category'].toString().toUpperCase(),
          ),
          onTap: () => _showPlaceDetails(place),
        ),
      );
    }
  }

  Color _getZoneColor(ZoneType type) {
    switch (type) {
      case ZoneType.safe:
        return Colors.green;
      case ZoneType.danger:
        return Colors.red;
      case ZoneType.accident:
        return Colors.orange;
    }
  }

  BitmapDescriptor _getMarkerIcon(ZoneType type) {
    switch (type) {
      case ZoneType.safe:
        return _safeZoneIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case ZoneType.danger:
        return _redZoneIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case ZoneType.accident:
        return _accidentZoneIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  String _getZoneName(ZoneType type) {
    switch (type) {
      case ZoneType.safe:
        return 'Safe Zone';
      case ZoneType.danger:
        return 'Danger Zone';
      case ZoneType.accident:
        return 'Accident Zone';
    }
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    if (_selectedFilter == 'All Places') return _places;
    if (_selectedFilter == 'Police') {
      return _places.where((p) => p['category'] == 'police').toList();
    }
    if (_selectedFilter == 'Hospital') {
      return _places.where((p) => p['category'] == 'hospital').toList();
    }
    if (_selectedFilter == 'Fire Brigade') {
      return _places.where((p) => p['category'] == 'fire_brigade').toList();
    }
    return _places;
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadZones();
              _loadSafetyPlaces();
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            circles: _circles,
            onTap: _onMapTap,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Places'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Police'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hospital'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Fire Brigade'),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredPlaces.length,
                  itemBuilder: (context, index) =>
                      _buildPlaceCard(_filteredPlaces[index]),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddPlaceDialog(),
        ),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Place'),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _updatePlaceMarkers();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    IconData iconData;
    Color iconColor = AppTheme.primary;

    if (place['category'] == 'police') {
      iconData = Icons.local_police;
    } else if (place['category'] == 'hospital') {
      iconData = Icons.local_hospital;
      iconColor = Colors.red;
    } else if (place['category'] == 'fire_brigade') {
      iconData = Icons.fire_extinguisher;
      iconColor = Colors.orange;
    } else {
      iconData = Icons.security;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          place['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place['description'].isNotEmpty) Text(place['description']),
            Text(
              'Added by: ${place['userName']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map, color: Colors.blue),
          onPressed: () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(place['lat'], place['lng'])),
            );
          },
        ),
        onTap: () => _showPlaceDetails(place),
      ),
    );
  }

  void _onMapTap(LatLng location) {
    // Show choice dialog: Add Place or Add Zone
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Map'),
        content: const Text('What would you like to add?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Show AddPlaceDialog
              showDialog(
                context: context,
                builder: (context) => AddPlaceDialog(initialPosition: location),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on),
                SizedBox(width: 8),
                Text('Place\n(Police/Hospital/Fire)'),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Show AddZoneDialog
              showDialog(
                context: context,
                builder: (context) => AddZoneDialog(
                  position: location,
                  onAdd: (type, radius, description) {
                    _addZone(location, type, radius, description);
                  },
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle),
                SizedBox(width: 8),
                Text('Zone\n(Safe/Danger/Accident)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showZoneOptions(String zoneId, ZoneType type, double radius) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getZoneName(type),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Radius: ${radius.toInt()} meters'),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Zone'),
              onTap: () async {
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final firestoreService = Provider.of<FirestoreService>(
                  context,
                  listen: false,
                );

                if (authService.userId != null) {
                  await firestoreService.deleteZone(
                    authService.userId!,
                    zoneId,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceDetails(Map<String, dynamic> place) {
    IconData iconData;
    Color iconColor = AppTheme.primary;

    if (place['category'] == 'police') {
      iconData = Icons.local_police;
    } else if (place['category'] == 'hospital') {
      iconData = Icons.local_hospital;
      iconColor = Colors.red;
    } else if (place['category'] == 'fire_brigade') {
      iconData = Icons.fire_extinguisher;
      iconColor = Colors.orange;
    } else {
      iconData = Icons.security;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: iconColor, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    place['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (place['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(child: Text(place['description'])),
                  ],
                ),
              ),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 10),
                Text('Added by: ${place['userName']}'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to Google Maps
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${place['lat']},${place['lng']}';
                  launchUrl(Uri.parse(url));
                },
                icon: const Icon(Icons.map),
                label: const Text('Open in Google Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addZone(
    LatLng location,
    String type,
    double radius,
    String? description,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId == null) return;

    final zoneId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create a readable name for the zone
    String zoneName;
    if (description != null && description.isNotEmpty) {
      zoneName = description;
    } else {
      // Use type-based default names
      if (type == 'safe') {
        zoneName = 'Safe Zone';
      } else if (type == 'danger') {
        zoneName = 'Danger Zone';
      } else if (type == 'accident') {
        zoneName = 'Accident Zone';
      } else {
        zoneName = 'Safety Zone';
      }
    }

    final zoneData = {
      'id': zoneId,
      'userId': authService.userId,
      'userName': authService.userDisplayName ?? 'Anonymous',
      'name': zoneName, // Add the name field
      'type': 'ZoneType.$type',
      'latitude': location.latitude,
      'longitude': location.longitude,
      'radius': radius,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await firestoreService.addZone(authService.userId!, zoneData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zone added successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error adding zone: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add zone: $e')));
      }
    }
  }
}
