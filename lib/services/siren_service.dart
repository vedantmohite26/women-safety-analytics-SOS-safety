import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SirenService {
  static final SirenService _instance = SirenService._internal();
  factory SirenService() => _instance;
  SirenService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> startSiren() async {
    if (_isPlaying) return;
    try {
      await _player.setSource(AssetSource('sounds/siren.mp3'));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.resume();
      _isPlaying = true;
    } catch (e) {
      debugPrint('Error starting siren: $e');
    }
  }

  Future<void> stopSiren() async {
    if (!_isPlaying) return;
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('Error stopping siren: $e');
    }
  }
}
