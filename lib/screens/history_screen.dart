import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_scaffold.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.userId;

    return GradientScaffold(
      appBar: AppBar(title: const Text('Alert History')),
      body: userId == null
          ? const Center(child: Text('Please sign in to view history'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sos_alerts')
                  .where('userId', isEqualTo: userId)
                  // .orderBy('timestamp', descending: true) // Temporarily disabled to fix index error
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final errorMessage = snapshot.error.toString();

                  // Check for specific error types
                  if (errorMessage.contains('index') ||
                      errorMessage.contains('FAILED_PRECONDITION')) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 64,
                              color: Colors.orange.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Database Index Required',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please create a Firestore index or wait a moment.',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (errorMessage.contains('PERMISSION_DENIED')) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Access Denied',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your Firestore security rules.',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (errorMessage.contains('UNAVAILABLE') ||
                      errorMessage.contains('network')) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Internet Connection',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check your internet connection.',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Generic error
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Error Loading History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final alerts = snapshot.data?.docs ?? [];

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No alert history',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your SOS alerts will appear here',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: alerts.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final alert = alerts[index].data() as Map<String, dynamic>;
                    final timestamp = alert['timestamp'] as Timestamp?;
                    final location = alert['location'] as GeoPoint?;
                    final status = alert['status'] as String? ?? 'unknown';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: AppTheme.glassDecoration,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: status == 'active'
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            status == 'active'
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            color: status == 'active'
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        title: Text(
                          status == 'active' ? 'SOS Alert' : 'Resolved Alert',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (timestamp != null)
                              Text(
                                _formatTimestamp(timestamp),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            if (location != null)
                              Text(
                                'Location: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: status == 'active'
                            ? Chip(
                                label: const Text(
                                  'Active',
                                  style: TextStyle(fontSize: 10),
                                ),
                                backgroundColor: Colors.red.shade50,
                                side: BorderSide(color: Colors.red.shade200),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
