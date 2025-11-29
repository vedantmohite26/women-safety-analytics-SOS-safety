import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
        });
      }
    } catch (e) {
      // Fallback
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('About & Safety'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade800, Colors.orange.shade50],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // App Logo & Version
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 64,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Safety Guardian',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'v$_version',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Emergency Numbers Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_in_talk, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          const Text(
                            'Emergency Numbers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _EmergencyButton(
                              icon: Icons.local_police,
                              label: 'Police',
                              number: '100',
                              color: Colors.blue.shade700,
                              onTap: () => _makePhoneCall('100'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _EmergencyButton(
                              icon: Icons.medical_services,
                              label: 'Ambulance',
                              number: '102',
                              color: Colors.red.shade700,
                              onTap: () => _makePhoneCall('102'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _EmergencyButton(
                              icon: Icons.support_agent,
                              label: 'Helpline',
                              number: '1091',
                              color: Colors.purple.shade700,
                              onTap: () => _makePhoneCall('1091'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _EmergencyButton(
                              icon: Icons.fire_truck,
                              label: 'Fire',
                              number: '101',
                              color: Colors.orange.shade800,
                              onTap: () => _makePhoneCall('101'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Guidelines Section
              const Text(
                'Safety Guidelines',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              _GuidelineTile(
                icon: Icons.sos,
                title: 'Using SOS Alert',
                content:
                    'Press and hold the SOS button for 3 seconds to activate. This will:\n\n'
                    '• Send your live location to emergency contacts\n'
                    '• Trigger a loud siren alarm\n'
                    '• Notify nearby users (if enabled)\n'
                    '• Alert the admin dashboard',
              ),
              _GuidelineTile(
                icon: Icons.security,
                title: 'Safe Zones',
                content:
                    'Safe Zones are verified areas marked on the map. \n\n'
                    '• Green zones are generally safe public spaces\n'
                    '• You can create your own safe zones\n'
                    '• Zones are shared with the community to help others',
              ),
              _GuidelineTile(
                icon: Icons.contact_phone,
                title: 'Emergency Contacts',
                content:
                    'Keep your emergency contacts updated. \n\n'
                    '• Add trusted family members or friends\n'
                    '• Verify their phone numbers\n'
                    '• They will receive SMS alerts with your location link',
              ),

              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Stay Safe, Stay Connected',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyButton({
    required this.icon,
    required this.label,
    required this.number,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidelineTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _GuidelineTile({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.orange.shade800),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              content,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
