import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Central service for audio feedback, sound effects, and text-to-speech
class AudioFeedbackService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;
  static bool _isPlaying = false;

  static bool get isPlaying => _isPlaying;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isPlaying = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
      });

      _flutterTts.setErrorHandler((_) {
        _isPlaying = false;
      });

      _isInitialized = true;
    } catch (_) {}
  }

  /// Play audible feedback sound
  static void playFeedbackSound() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Speak text aloud using native phone TTS
  static Future<void> speak(String text, {String? language}) async {
    if (text.trim().isEmpty) return;
    await init();
    try {
      if (language != null) {
        await _flutterTts.setLanguage(language);
      }
      _isPlaying = true;
      await _flutterTts.speak(text);
    } catch (_) {
      _isPlaying = false;
    }
  }

  /// Stop current audio playback
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isPlaying = false;
    } catch (_) {}
  }
}

