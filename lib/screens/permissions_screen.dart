import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionsScreen({super.key, required this.onPermissionsGranted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final Map<Permission, bool> _permissionStatus = {};
  bool _isRequesting = false;
  int _androidSdkInt = 0;

  @override
  void initState() {
    super.initState();
    _initDeviceInfo();
  }

  Future<void> _initDeviceInfo() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (mounted) {
        setState(() {
          _androidSdkInt = androidInfo.version.sdkInt;
        });
        _checkPermissions();
      }
    } else {
      _checkPermissions();
    }
  }

  List<Permission> get _requiredPermissions {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
      Permission.notification,
      Permission.microphone,
    ];

    if (Platform.isAndroid) {
      if (_androidSdkInt >= 33) {
        // Android 13+ (API 33+)
        permissions.add(Permission.photos);
        permissions.add(Permission.videos);
        permissions.add(Permission.audio);
      } else {
        // Android 12 and below
        permissions.add(Permission.storage);
      }
    } else {
      // iOS and others
      permissions.add(Permission.storage);
    }

    return permissions;
  }

  Future<void> _checkPermissions() async {
    for (var permission in _requiredPermissions) {
      final status = await permission.status;
      if (mounted) {
        setState(() {
          _permissionStatus[permission] = status.isGranted;
        });
      }
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
    ];

    // Add storage/media permissions based on version
    if (Platform.isAndroid) {
      if (_androidSdkInt >= 33) {
        permissions.add(Permission.photos);
        permissions.add(Permission.videos);
        permissions.add(Permission.audio);
      } else {
        permissions.add(Permission.storage);
      }
    }

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
    bool basic =
        (_permissionStatus[Permission.location] ?? false) &&
        (_permissionStatus[Permission.notification] ?? false);

    // Check storage/media
    bool storage = false;
    if (Platform.isAndroid && _androidSdkInt >= 33) {
      // For Android 13+, consider storage granted if at least one media type is allowed
      // or if user doesn't strictly need all of them. Let's be lenient.
      storage =
          (_permissionStatus[Permission.photos] ?? false) ||
          (_permissionStatus[Permission.videos] ?? false) ||
          (_permissionStatus[Permission.audio] ?? false);
    } else {
      storage = _permissionStatus[Permission.storage] ?? false;
    }

    // We make storage mandatory as requested
    return basic && storage;
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
                      // Conditional Storage UI
                      if (Platform.isAndroid && _androidSdkInt >= 33) ...[
                        _buildPermissionTile(
                          icon: Icons.image,
                          title: 'Photos & Videos',
                          description: 'Save evidence',
                          permission: Permission.photos,
                          isRequired: false,
                        ),
                        _buildPermissionTile(
                          icon: Icons.audiotrack,
                          title: 'Music & Audio',
                          description: 'Save audio recordings',
                          permission: Permission.audio,
                          isRequired: false,
                        ),
                      ] else ...[
                        _buildPermissionTile(
                          icon: Icons.storage,
                          title: 'Storage',
                          description: 'Save audio recordings',
                          permission: Permission.storage,
                          isRequired: false,
                        ),
                      ],
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
