import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_scaffold.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sosAlertsEnabled = true;
  bool _safetyZoneAlertsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sosAlertsEnabled = prefs.getBool('sos_alerts_enabled') ?? true;
        _safetyZoneAlertsEnabled =
            prefs.getBool('safety_zone_alerts_enabled') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSOSAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_alerts_enabled', value);
    setState(() {
      _sosAlertsEnabled = value;
    });
  }

  Future<void> _toggleSafetyZoneAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safety_zone_alerts_enabled', value);
    setState(() {
      _safetyZoneAlertsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader('Notifications'),
                _buildSwitchTile(
                  title: 'SOS Alerts',
                  subtitle: 'Receive emergency SOS notifications',
                  value: _sosAlertsEnabled,
                  onChanged: _toggleSOSAlerts,
                  icon: Icons.notifications_active,
                ),
                _buildSwitchTile(
                  title: 'Safety Zone Alerts',
                  subtitle: 'Get notified about safety zone activity',
                  value: _safetyZoneAlertsEnabled,
                  onChanged: _toggleSafetyZoneAlerts,
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Permissions'),
                _buildPermissionTile(
                  title: 'Location',
                  subtitle: 'Required for emergency tracking',
                  icon: Icons.location_on,
                  permission: 'location',
                  isRequired: true,
                ),
                _buildPermissionTile(
                  title: 'Notifications',
                  subtitle: 'Required for alerts',
                  icon: Icons.notifications,
                  permission: 'notification',
                  isRequired: true,
                ),
                _buildPermissionTile(
                  title: 'Contacts',
                  subtitle: 'Access emergency contacts',
                  icon: Icons.contacts,
                  permission: 'contacts',
                  isRequired: false,
                ),
                _buildPermissionTile(
                  title: 'Phone',
                  subtitle: 'Make emergency calls',
                  icon: Icons.phone,
                  permission: 'phone',
                  isRequired: false,
                ),
                _buildPermissionTile(
                  title: 'SMS',
                  subtitle: 'Send SOS messages',
                  icon: Icons.sms,
                  permission: 'sms',
                  isRequired: false,
                ),
                _buildPermissionTile(
                  title: 'Microphone',
                  subtitle: 'Record audio during emergencies',
                  icon: Icons.mic,
                  permission: 'microphone',
                  isRequired: false,
                ),
                _buildPermissionTile(
                  title: 'Storage',
                  subtitle: 'Save audio recordings',
                  icon: Icons.storage,
                  permission: 'storage',
                  isRequired: false,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Support'),
                _buildActionTile(
                  title: 'About & Safety',
                  icon: Icons.info_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassDecoration,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        activeThumbColor: AppTheme.primary,
        activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? Colors.black87;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassDecoration,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: themeColor),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
        ),
        trailing: Icon(Icons.chevron_right, color: themeColor),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String permission,
    required bool isRequired,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassDecoration,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isRequired)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: () => _requestPermission(permission),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('Grant', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Future<void> _requestPermission(String permissionName) async {
    Permission? permission;

    switch (permissionName) {
      case 'location':
        permission = Permission.location;
        break;
      case 'notification':
        permission = Permission.notification;
        break;
      case 'contacts':
        permission = Permission.contacts;
        break;
      case 'phone':
        permission = Permission.phone;
        break;
      case 'sms':
        permission = Permission.sms;
        break;
      case 'microphone':
        permission = Permission.microphone;
        break;
      case 'storage':
        permission = Permission.storage;
        break;
    }

    if (permission != null) {
      final status = await permission.request();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.isGranted
                  ? '$permissionName permission granted'
                  : '$permissionName permission denied',
            ),
            backgroundColor: status.isGranted ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
