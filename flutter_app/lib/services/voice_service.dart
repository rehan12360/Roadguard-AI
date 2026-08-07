import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  Future<void> speakAlert(String hazardType, int distanceMeters) async {
    if (!_ready) await init();
    final message =
        'Warning. $hazardType detected ${distanceMeters} meters ahead.';
    await _tts.speak(message);
  }

  Future<void> speak(String text) async {
    if (!_ready) await init();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
