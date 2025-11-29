import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionsScreen({super.key, required this.onPermissionsGranted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final Map<Permission, bool> _permissionStatus = {};
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
      Permission.notification,
      Permission.microphone,
      Permission.storage,
    ];

    for (var permission in permissions) {
      final status = await permission.status;
      setState(() {
        _permissionStatus[permission] = status.isGranted;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);

    final permissions = [
      Permission.location,
      Permission.notification,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
      Permission.microphone,
      Permission.storage,
    ];

    // Check for permanently denied permissions first
    final permanentlyDenied = <Permission>[];
    for (var permission in permissions) {
      if (await permission.isPermanentlyDenied) {
        permanentlyDenied.add(permission);
      }
    }

    if (permanentlyDenied.isNotEmpty && mounted) {
      setState(() => _isRequesting = false);
      _showSettingsDialog();
      return;
    }

    // Request permissions
    final statuses = await permissions.request();

    if (mounted) {
      setState(() {
        for (var entry in statuses.entries) {
          _permissionStatus[entry.key] = entry.value.isGranted;
        }
        _isRequesting = false;
      });

      // Check if all critical permissions are granted
      if (_allCriticalPermissionsGranted()) {
        widget.onPermissionsGranted();
      } else {
        // Check if any were permanently denied after request
        final nowPermanentlyDenied = <Permission>[];
        for (var permission in permissions) {
          if (await permission.isPermanentlyDenied) {
            nowPermanentlyDenied.add(permission);
          }
        }

        if (nowPermanentlyDenied.isNotEmpty) {
          _showSettingsDialog();
        }
      }
    }
  }

  bool _allCriticalPermissionsGranted() {
    // Location and notification are critical
    return (_permissionStatus[Permission.location] ?? false) &&
        (_permissionStatus[Permission.notification] ?? false);
  }

  Future<void> _requestSinglePermission(Permission permission) async {
    // Check if permanently denied
    if (await permission.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog();
      }
      return;
    }

    // Request the permission
    final status = await permission.request();

    if (mounted) {
      setState(() {
        _permissionStatus[permission] = status.isGranted;
      });

      // If denied and now permanently denied, show settings dialog
      if (!status.isGranted && await permission.isPermanentlyDenied) {
        if (mounted) {
          _showSettingsDialog();
        }
      } else if (status.isGranted) {
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission granted'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }

        // Check if all critical permissions are now granted
        if (_allCriticalPermissionsGranted()) {
          // Optional: Auto-continue if all critical permissions granted
          // widget.onPermissionsGranted();
        }
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Some permissions are permanently denied. Please enable them in app settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // Recheck permissions when user returns
              await _checkPermissions();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Permissions Required',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'For your safety, we need access to:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                Expanded(
                  child: ListView(
                    children: [
                      _buildPermissionTile(
                        icon: Icons.location_on,
                        title: 'Location',
                        description: 'Track your location during emergencies',
                        permission: Permission.location,
                        isRequired: true,
                      ),
                      _buildPermissionTile(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        description: 'Send you alerts and safety updates',
                        permission: Permission.notification,
                        isRequired: true,
                      ),
                      _buildPermissionTile(
                        icon: Icons.contacts,
                        title: 'Contacts',
                        description: 'Access emergency contacts',
                        permission: Permission.contacts,
                        isRequired: false,
                      ),
                      _buildPermissionTile(
                        icon: Icons.phone,
                        title: 'Phone',
                        description: 'Make emergency calls',
                        permission: Permission.phone,
                        isRequired: false,
                      ),
                      _buildPermissionTile(
                        icon: Icons.sms,
                        title: 'SMS',
                        description: 'Send SOS messages',
                        permission: Permission.sms,
                        isRequired: false,
                      ),
                      _buildPermissionTile(
                        icon: Icons.mic,
                        title: 'Microphone',
                        description: 'Record audio during emergencies',
                        permission: Permission.microphone,
                        isRequired: false,
                      ),
                      _buildPermissionTile(
                        icon: Icons.storage,
                        title: 'Storage',
                        description: 'Save audio recordings',
                        permission: Permission.storage,
                        isRequired: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _requestAllPermissions,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Grant Permissions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                if (_allCriticalPermissionsGranted())
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: widget.onPermissionsGranted,
                        child: const Text('Continue to App'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required Permission permission,
    required bool isRequired,
  }) {
    final isGranted = _permissionStatus[permission] ?? false;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isGranted ? null : () => _requestSinglePermission(permission),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isGranted
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.orange.shade100,
            child: Icon(
              icon,
              color: isGranted
                  ? theme.colorScheme.primary
                  : Colors.orange.shade700,
            ),
          ),
          title: Row(
            children: [
              Text(title),
              if (isRequired)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(description),
          trailing: Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted ? theme.colorScheme.primary : Colors.grey,
          ),
        ),
      ),
    );
  }
}
