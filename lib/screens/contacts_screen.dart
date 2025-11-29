import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

import 'package:geolocator/geolocator.dart';
import 'sos_alert_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    try {
      await firestoreService.addEmergencyContact(
        authService.userId!,
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );

      _nameController.clear();
      _phoneController.clear();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contact added successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding contact: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteContact(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Remove $name from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId == null) return;

    try {
      await firestoreService.deleteEmergencyContact(authService.userId!, docId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddContactDialog() {
    _nameController.clear();
    _phoneController.clear();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Trusted Contact',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addContact,
                child: const Text('Add Contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareLocationOnly() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId == null) return;

    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      // Get emergency contacts
      final contactsSnapshot = await firestoreService
          .getEmergencyContacts(authService.userId!)
          .first;

      if (contactsSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No emergency contacts found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Send SMS to all contacts
      for (var doc in contactsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final phone = data['phone'] as String?;
        if (phone != null) {
          final smsUrl = 'sms:$phone?body=My current location: $locationUrl';
          await launchUrl(Uri.parse(smsUrl));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location shared with emergency contacts'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _quickCallFirstContact() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (authService.userId == null) return;

    try {
      // Get emergency contacts
      final contactsSnapshot = await firestoreService
          .getEmergencyContacts(authService.userId!)
          .first;

      if (contactsSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No emergency contacts found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get first contact
      final firstContact =
          contactsSnapshot.docs.first.data() as Map<String, dynamic>;
      final phone = firstContact['phone'] as String?;

      if (phone != null) {
        await launchUrl(Uri.parse('tel:$phone'));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact has no phone number'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final user = authService.currentUser;
    final userName = user?.displayName ?? 'User';
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      body: Stack(
        children: [
          // Map Background
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 13.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Overlay to fade map
          Container(color: Colors.white.withValues(alpha: 0.85)),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $userName',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // SOS Button
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SOSAlertScreen(),
                            ),
                          );
                        },
                        customBorder: const CircleBorder(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 40,
                              color: Colors.white,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'TAP FOR SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Quick Actions Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.5,
                    children: [
                      _buildQuickAction(
                        context,
                        'Share Location',
                        Icons.location_on_outlined,
                        Colors.pink.shade50,
                        theme.colorScheme.primary,
                        _shareLocationOnly,
                      ),
                      _buildQuickAction(
                        context,
                        'Quick Call',
                        Icons.phone_outlined,
                        Colors.pink.shade50,
                        theme.colorScheme.primary,
                        _quickCallFirstContact,
                      ),
                      _buildQuickAction(
                        context,
                        'Emergency Services',
                        Icons.emergency,
                        Colors.red.shade50,
                        Colors.red,
                        () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Emergency Services'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildEmergencyServiceCard(
                                          '100',
                                          'Police',
                                          Icons.local_police,
                                          Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildEmergencyServiceCard(
                                          '101',
                                          'Fire',
                                          Icons.fire_extinguisher,
                                          Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildEmergencyServiceCard(
                                          '102',
                                          'Ambulance',
                                          Icons.local_hospital,
                                          Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildEmergencyServiceCard(
                                          '1091',
                                          'Women Helpline',
                                          Icons.support_agent,
                                          Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        context,
                        'Safety Tips',
                        Icons.info_outline,
                        Colors.pink.shade50,
                        theme.colorScheme.primary,
                        () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Safety Tips'),
                              content: const Text(
                                '1. Stay aware of your surroundings.\n'
                                '2. Keep your phone charged.\n'
                                '3. Share your live location with trusted contacts.\n'
                                '4. Trust your instincts.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Trusted Contacts Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trusted Contacts',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddContactDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add New'),
                      ),
                    ],
                  ),
                ),

                // Contacts List
                StreamBuilder<QuerySnapshot>(
                  stream: authService.userId != null
                      ? firestoreService.getEmergencyContacts(
                          authService.userId!,
                        )
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userContacts = snapshot.data!.docs;

                    if (userContacts.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_add_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Add trusted contacts for emergencies',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: userContacts.length,
                      itemBuilder: (context, index) {
                        final data =
                            userContacts[index].data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Unknown';
                        final phone = data['phone'] ?? '';
                        final docId = userContacts[index].id;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary
                                  .withValues(alpha: 0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(phone),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: () => _deleteContact(docId, name),
                            ),
                            onTap: () async {
                              if (phone.isNotEmpty) {
                                final uri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyServiceCard(
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('tel:$number');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not dial $number'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              number,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
