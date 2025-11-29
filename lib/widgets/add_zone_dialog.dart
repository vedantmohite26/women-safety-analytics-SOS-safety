import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddZoneDialog extends StatefulWidget {
  final LatLng position;
  final Function(String type, double radius, String? description) onAdd;

  const AddZoneDialog({super.key, required this.position, required this.onAdd});

  @override
  State<AddZoneDialog> createState() => _AddZoneDialogState();
}

class _AddZoneDialogState extends State<AddZoneDialog> {
  String _selectedType = 'safe';
  double _radius = 100.0;
  final TextEditingController _descriptionController = TextEditingController();

  final Map<String, Map<String, dynamic>> _zoneTypes = {
    'safe': {'label': 'Safe Zone', 'icon': Icons.shield, 'color': Colors.green},
    'danger': {
      'label': 'Danger Zone',
      'icon': Icons.warning,
      'color': Colors.red,
    },
    'accident': {
      'label': 'Accident Zone',
      'icon': Icons.car_crash,
      'color': Colors.orange,
    },
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Safety Zone'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone Type Selection
            RadioGroup<String>(
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zone Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._zoneTypes.entries.map((entry) {
                    return RadioListTile<String>(
                      value: entry.key,
                      title: Row(
                        children: [
                          Icon(
                            entry.value['icon'] as IconData,
                            color: entry.value['color'] as Color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(entry.value['label'] as String),
                        ],
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Radius Slider
            Text(
              'Radius: ${_radius.toInt()}m',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: _radius,
              min: 50,
              max: 500,
              divisions: 9,
              label: '${_radius.toInt()}m',
              onChanged: (value) {
                setState(() => _radius = value);
              },
            ),
            const SizedBox(height: 16),

            // Description (Optional)
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g., Well-lit area with security',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAdd(
              _selectedType,
              _radius,
              _descriptionController.text.isEmpty
                  ? null
                  : _descriptionController.text,
            );
            Navigator.pop(context);
          },
          child: const Text('Add Zone'),
        ),
      ],
    );
  }
}
