import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AudioRecorderButton extends StatefulWidget {
  final Function(String path) onRecordingComplete;

  const AudioRecorderButton({super.key, required this.onRecordingComplete});

  @override
  State<AudioRecorderButton> createState() => _AudioRecorderButtonState();
}

class _AudioRecorderButtonState extends State<AudioRecorderButton>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Check and request permissions
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission denied. Please enable in Settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/recording_$timestamp.m4a';

      await _audioRecorder.start(const RecordConfig(), path: path);

      setState(() {
        _isRecording = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording started. Release to stop.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        widget.onRecordingComplete(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isRecording) {
          _stopRecording();
        } else {
          _startRecording();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRecording
                  ? Colors.red.withValues(
                      alpha: 0.2 + (_animationController.value * 0.2),
                    )
                  : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _isRecording
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                  blurRadius: _isRecording ? 12 : 8,
                  spreadRadius: _isRecording ? 4 : 0,
                ),
              ],
            ),
            child: Icon(
              _isRecording
                  ? Icons.stop
                  : Icons.mic, // Changed icon to Stop when recording
              color: _isRecording ? Colors.red : Colors.grey.shade700,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}
