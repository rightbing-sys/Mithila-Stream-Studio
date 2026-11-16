import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsLanguageOption {
  final String label;
  final String code;
  final String shortCode;

  const TtsLanguageOption({
    required this.label,
    required this.code,
    required this.shortCode,
  });
}

class TtsService {
  static const List<TtsLanguageOption> supportedLanguages = [
    TtsLanguageOption(label: 'English', code: 'en-US', shortCode: 'EN'),
    TtsLanguageOption(label: 'Hindi', code: 'hi-IN', shortCode: 'HI'),
    TtsLanguageOption(label: 'Urdu', code: 'ur-PK', shortCode: 'UR'),
    TtsLanguageOption(label: 'Arabic', code: 'ar-SA', shortCode: 'AR'),
  ];

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    void Function(String error)? onError,
    void Function(String word)? onProgress,
  }) async {
    _flutterTts.setStartHandler(() {
      onStart?.call();
    });
    _flutterTts.setCompletionHandler(() {
      onComplete?.call();
    });
    _flutterTts.setCancelHandler(() {
      onCancel?.call();
    });
    _flutterTts.setErrorHandler((msg) {
      onError?.call(msg.toString());
    });
    _flutterTts.setProgressHandler((text, start, end, word) {
      onProgress?.call(word);
    });

    if (_isInitialized) return;

    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FlutterTts init error: $e');
      }
      onError?.call(e.toString());
    }
  }

  Future<void> speak(
    String text, {
    String language = 'en-US',
    double speechRate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _flutterTts.stop();
    await _flutterTts.setLanguage(language);
    await _flutterTts.setSpeechRate(speechRate.clamp(0.1, 1.0));
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
    await _flutterTts.speak(trimmed);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<List<String>> getAvailableLanguages() async {
    try {
      final raw = await _flutterTts.getLanguages;
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  void dispose() {
    _flutterTts.stop();
  }
}
