import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service to handle audio recording for SOS alerts
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start recording audio
  /// Returns the path where the recording will be saved
  Future<String?> startRecording() async {
    try {
      // Check and request permission
      final hasPermission = await hasMicrophonePermission();
      if (!hasPermission) {
        final granted = await requestMicrophonePermission();
        if (!granted) {
          debugPrint('AudioService: Microphone permission denied');
          return null;
        }
      }

      // Create directory for SOS audio files
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String sosAudioDir = '${appDocDir.path}/SOS_Audio';
      final Directory sosDir = Directory(sosAudioDir);

      if (!await sosDir.exists()) {
        await sosDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final String timestamp = DateTime.now().toIso8601String().replaceAll(
        ':',
        '-',
      );
      _currentRecordingPath = '$sosAudioDir/sos_$timestamp.m4a';

      // Start recording
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );
        _isRecording = true;
        debugPrint('AudioService: Recording started at $_currentRecordingPath');
        return _currentRecordingPath;
      } else {
        debugPrint('AudioService: No permission to record');
        return null;
      }
    } catch (e) {
      debugPrint('AudioService: Error starting recording: $e');
      return null;
    }
  }

  /// Stop recording audio
  /// Returns the path of the saved recording
  Future<String?> stopRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        _isRecording = false;
        debugPrint('AudioService: Recording stopped at $path');
        return path;
      }
      return null;
    } catch (e) {
      debugPrint('AudioService: Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel current recording (stop and delete file)
  Future<void> cancelRecording() async {
    try {
      await stopRecording();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('AudioService: Recording cancelled and deleted');
        }
      }
      _currentRecordingPath = null;
    } catch (e) {
      debugPrint('AudioService: Error cancelling recording: $e');
    }
  }

  /// Get all SOS audio recordings
  Future<List<FileSystemEntity>> getSavedRecordings() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String sosAudioDir = '${appDocDir.path}/SOS_Audio';
      final Directory sosDir = Directory(sosAudioDir);

      if (await sosDir.exists()) {
        return sosDir
            .listSync()
            .where((entity) => entity is File && entity.path.endsWith('.m4a'))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('AudioService: Error getting recordings: $e');
      return [];
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _recorder.dispose();
  }
}
