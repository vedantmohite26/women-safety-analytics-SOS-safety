import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_scaffold.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _hubMessageController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chatService.cleanupExpiredMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hubMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.userId;

    if (userId == null) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Please sign in to use chat')),
      );
    }

    return GradientScaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.chat), text: 'Active Chats'),
                Tab(icon: Icon(Icons.people), text: 'Nearby Users'),
              ],
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildActiveChats(userId),
                  _buildNearbyUsersWithSearch(userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChats(String userId) {
    return FutureBuilder<Position?>(
      future: _getCurrentLocation(),
      builder: (context, locationSnapshot) {
        if (locationSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (locationSnapshot.hasError || locationSnapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Location permission required',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enable location to join the hub',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }

        final position = locationSnapshot.data!;
        return _buildLocationHub(userId, position);
      },
    );
  }

  /// Get current location with permission handling
  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Build the location-based hub UI
  Widget _buildLocationHub(String userId, Position position) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    // Update user location in Firestore
    firestoreService.updateUserLocation(
      userId,
      position.latitude,
      position.longitude,
      isVisible: true,
    );

    return Column(
      children: [
        // Hub header with user count
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.hub_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Hub',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<int>(
                      future: _chatService.getNearbyHubUsers(
                        userLat: position.latitude,
                        userLon: position.longitude,
                        radiusInKm: 10,
                      ),
                      builder: (context, snapshot) {
                        final userCount = snapshot.data ?? 0;
                        return Row(
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$userCount ${userCount == 1 ? 'user' : 'users'} nearby (10km)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.primary,
                onPressed: () {
                  if (mounted) setState(() {});
                },
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getHubMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error.toString();
                  final isIndexError =
                      error.contains('failed-precondition') ||
                      error.contains('requires an index');

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isIndexError
                                ? Icons.settings_system_daydream
                                : Icons.error_outline_rounded,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isIndexError
                                ? 'Database Setup Required'
                                : 'Error loading messages',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isIndexError
                                ? 'Please check the Firebase Console to create the required index for hub messages.'
                                : 'Please check your connection',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isIndexError) ...[
                            const SizedBox(height: 16),
                            SelectableText(
                              'Create composite index on hub_messages:\nexpiresAt (ASC) + timestamp (ASC)',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMessages = snapshot.data?.docs ?? [];

                // Filter messages by distance (10km radius)
                final nearbyMessages = allMessages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final senderLocation = data['senderLocation'] as GeoPoint?;

                  if (senderLocation == null) return false;

                  final distance = _calculateDistance(
                    position.latitude,
                    position.longitude,
                    senderLocation.latitude,
                    senderLocation.longitude,
                  );

                  return distance <= 10000; // 10km in meters
                }).toList();

                if (nearbyMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppTheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to say hello!',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: nearbyMessages.length,
                  itemBuilder: (context, index) {
                    final message =
                        nearbyMessages[index].data() as Map<String, dynamic>;
                    final senderId = message['senderId'] as String;
                    final senderName = message['senderName'] as String;
                    final text = message['text'] as String;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final isMe = senderId == userId;

                    return _buildHubMessageBubble(
                      text: text,
                      senderName: senderName,
                      isMe: isMe,
                      timestamp: timestamp,
                    );
                  },
                );
              },
            ),
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _hubMessageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        counterStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendHubMessage(
                        userId,
                        authService.username ??
                            authService.userDisplayName ??
                            'User',
                        position,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _sendHubMessage(
                      userId,
                      authService.username ??
                          authService.userDisplayName ??
                          'User',
                      position,
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Calculate distance between two coordinates in meters
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R * 1000; R = 6371 km
  }

  /// Send a message to the hub
  Future<void> _sendHubMessage(
    String userId,
    String userName,
    Position position,
  ) async {
    if (_hubMessageController.text.trim().isEmpty) return;

    final text = _hubMessageController.text.trim();
    _hubMessageController.clear();

    try {
      await _chatService.sendHubMessage(
        senderId: userId,
        senderName: userName,
        latitude: position.latitude,
        longitude: position.longitude,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  /// Build an enhanced hub message bubble with improved UI
  Widget _buildHubMessageBubble({
    required String text,
    required String senderName,
    required bool isMe,
    Timestamp? timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(
                senderName[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatTime(timestamp.toDate()),
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyUsersWithSearch(String userId) {
    return Column(
      children: [
        // Search bar only in Nearby Users tab
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade200,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(child: _buildNearbyUsers(userId)),
      ],
    );
  }

  Widget _buildNearbyUsers(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];
        var nearbyUsers = users.where((doc) => doc.id != userId).toList();

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          nearbyUsers = nearbyUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final userName = (data['username'] ?? data['displayName'] ?? '')
                .toString()
                .toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return userName.contains(_searchQuery) ||
                email.contains(_searchQuery);
          }).toList();
        }

        if (nearbyUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No users found'
                      : 'No users match "$_searchQuery"',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) setState(() {});
          },
          child: ListView.builder(
            itemCount: nearbyUsers.length,
            itemBuilder: (context, index) {
              final user = nearbyUsers[index].data() as Map<String, dynamic>;
              final otherUserId = nearbyUsers[index].id;
              final userName =
                  user['username'] ?? user['displayName'] ?? 'Unknown User';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    userName[0].toUpperCase(),
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
                title: Text('@$userName'),
                subtitle: Text(user['email'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () async {
                    final authService = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    final currentUserName =
                        authService.username ??
                        authService.userDisplayName ??
                        'User';

                    final chatId = await _chatService.getOrCreateChat(
                      userId,
                      otherUserId,
                      currentUserName,
                      userName,
                    );

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatConversationScreen(
                          chatId: chatId,
                          otherUserId: otherUserId,
                          otherUserName: userName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
