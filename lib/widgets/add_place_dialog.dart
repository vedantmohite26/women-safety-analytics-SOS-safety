import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class AddPlaceDialog extends StatefulWidget {
  final LatLng? initialPosition;
  const AddPlaceDialog({super.key, this.initialPosition});

  @override
  State<AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<AddPlaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'police';
  bool _isLoading = false;
  LatLng? _currentPosition;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'police', 'label': 'Police Station', 'icon': Icons.local_police},
    {'value': 'hospital', 'label': 'Hospital', 'icon': Icons.local_hospital},
    {
      'value': 'fire_brigade',
      'label': 'Fire Brigade',
      'icon': Icons.fire_extinguisher,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(
          () =>
              _currentPosition = LatLng(position.latitude, position.longitude),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _submitPlace() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting location... Please wait')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      await firestoreService.addSafetyPlace(
        userId: authService.userId!,
        userName: authService.userDisplayName ?? 'Unknown User',
        name: _nameController.text.trim(),
        category: _selectedCategory,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Safety place added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding place: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_location_alt,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Safety Place',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category Selector
                const Text(
                  'Place Category',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category['value'];
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category['icon'] as IconData, size: 18),
                          const SizedBox(width: 4),
                          Text(category['label'] as String),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(
                          () => _selectedCategory = category['value'] as String,
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Place Name *',
                    hintText: 'e.g., City Hospital',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter place name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Field (Optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Any additional details',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // GPS Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPosition != null
                              ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                              : 'Getting GPS location...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitPlace,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add Place'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
