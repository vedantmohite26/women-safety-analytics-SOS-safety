import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'dart:async';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool _isAccepted = false;
  Timer? _timer;
  int _seconds = 0;

  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();

  @override
  void initState() {
    super.initState();
    _playRingtone();
  }

  Future<void> _playRingtone() async {
    try {
      // Use generic play with asAlarm: true to bypass silent mode and ensure audibility
      await _ringtonePlayer.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
      // Fallback to simple ringtone if generic play fails
      try {
        await _ringtonePlayer.playRingtone(looping: true);
      } catch (e) {
        debugPrint('Fallback error: $e');
      }
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  void _acceptCall() {
    _stopRingtone();
    setState(() {
      _isAccepted = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopRingtone();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Section: Caller Info
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Mom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isAccepted
                        ? _formatDuration(_seconds)
                        : 'Incoming call...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Section: Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
              child: _isAccepted
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCallButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          label: 'End',
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCallButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          label: 'Decline',
                          onTap: () => Navigator.pop(context),
                        ),
                        _buildCallButton(
                          icon: Icons.call,
                          color: Colors.green,
                          label: 'Accept',
                          onTap: _acceptCall,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }
}
