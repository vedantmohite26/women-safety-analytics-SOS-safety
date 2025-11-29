import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_scaffold.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  String? _blockchainId;
  String? _username;
  String? _contactPhoneNumber;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      final blockchainId = await firestoreService.getBlockchainId(
        authService.userId!,
      );
      final username = await firestoreService.getUsername(authService.userId!);
      final contactPhone = await firestoreService.getContactPhoneNumber(
        authService.userId!,
      );

      if (mounted) {
        setState(() {
          _blockchainId = blockchainId;
          _username = username;
          _contactPhoneNumber = contactPhone;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _copyBlockchainId() {
    if (_blockchainId != null) {
      Clipboard.setData(ClipboardData(text: _blockchainId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blockchain ID copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showEditPhoneDialog() async {
    final controller = TextEditingController(text: _contactPhoneNumber ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Contact Number'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+91XXXXXXXXXX',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              helperText: 'Include country code (e.g., +91)',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a phone number';
              }
              if (!RegExp(r'^\+[1-9]\d{9,14}$').hasMatch(value)) {
                return 'Format: +CountryCodeNumber (e.g., +919876543210)';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
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
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  await firestoreService.updateContactPhoneNumber(
                    authService.userId!,
                    controller.text.trim(),
                    verified: false,
                  );

                  if (!mounted) return;

                  final newPhone = controller.text.trim();
                  setState(() {
                    _contactPhoneNumber = newPhone;
                  });

                  if (!mounted) return;

                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Contact number saved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to save: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    return GradientScaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Picture
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: authService.userPhotoURL != null
                          ? NetworkImage(authService.userPhotoURL!)
                          : null,
                      child: authService.userPhotoURL == null
                          ? Icon(
                              Icons.person,
                              size: 60,
                              color: theme.colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Display Name
                  Text(
                    authService.userDisplayName ?? 'User',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Username
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '@${_username ?? 'loading...'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email
                  Text(
                    authService.userEmail ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Blockchain ID Card
                  Container(
                    decoration: AppTheme.glassDecoration,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Blockchain ID',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _blockchainId ?? 'Not generated',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: _blockchainId != null
                                      ? _copyBlockchainId
                                      : null,
                                  tooltip: 'Copy to clipboard',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your unique, immutable identifier',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Info Card
                  Container(
                    decoration: AppTheme.glassDecoration,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.alternate_email),
                          title: const Text('Username'),
                          subtitle: Text(_username ?? 'Generating...'),
                          trailing: _username != null
                              ? IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _username!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Username copied to clipboard',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  tooltip: 'Copy username',
                                )
                              : null,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(authService.userEmail ?? 'N/A'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.contact_phone),
                          title: const Text('Contact Number'),
                          subtitle: Text(
                            _contactPhoneNumber ?? 'Not set',
                            style: TextStyle(
                              color: _contactPhoneNumber != null
                                  ? null
                                  : Colors.grey.shade500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _showEditPhoneDialog,
                                tooltip: 'Edit contact number',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
