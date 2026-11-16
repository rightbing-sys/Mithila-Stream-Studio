import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechLanguageOption {
  final String label;
  final String localeId;
  final String shortCode;

  const SpeechLanguageOption({
    required this.label,
    required this.localeId,
    required this.shortCode,
  });
}

class CaptionCue {
  final String id;
  final String text;
  final Duration start;
  final Duration end;
  final String localeId;
  final double confidence;

  const CaptionCue({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    required this.localeId,
    this.confidence = 1.0,
  });

  CaptionCue copyWith({
    String? id,
    String? text,
    Duration? start,
    Duration? end,
    String? localeId,
    double? confidence,
  }) {
    return CaptionCue(
      id: id ?? this.id,
      text: text ?? this.text,
      start: start ?? this.start,
      end: end ?? this.end,
      localeId: localeId ?? this.localeId,
      confidence: confidence ?? this.confidence,
    );
  }
}

class SpeechToTextService {
  static const List<SpeechLanguageOption> supportedLanguages = [
    SpeechLanguageOption(label: 'English', localeId: 'en_US', shortCode: 'EN'),
    SpeechLanguageOption(label: 'Hindi', localeId: 'hi_IN', shortCode: 'HI'),
    SpeechLanguageOption(label: 'Urdu', localeId: 'ur_PK', shortCode: 'UR'),
    SpeechLanguageOption(label: 'Arabic', localeId: 'ar_SA', shortCode: 'AR'),
  ];

  final SpeechToText _speech = SpeechToText();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;
  String get lastStatus => _speech.lastStatus;
  SpeechRecognitionError? get lastError => _speech.lastError;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String errorMessage)? onError,
  }) async {
    if (_isInitialized && _speech.isAvailable) {
      return true;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) => onStatus?.call(status),
        onError: (error) => onError?.call(error.errorMsg),
        debugLogging: kDebugMode,
      );
      _isInitialized = available;
      return available;
    } catch (e) {
      _isInitialized = false;
      onError?.call(e.toString());
      return false;
    }
  }

  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return const [];
    }
    return _speech.locales();
  }

  /// Resolves a preferred locale (e.g. 'hi_IN') against device-supported locales
  /// by matching exact ID first, then language prefix (e.g. 'hi').
  String resolveLocaleId(String preferredLocaleId, List<LocaleName> deviceLocales) {
    if (deviceLocales.isEmpty) return preferredLocaleId;
    final normalizedPreferred = preferredLocaleId.replaceAll('-', '_').toLowerCase();
    for (final locale in deviceLocales) {
      if (locale.localeId.replaceAll('-', '_').toLowerCase() == normalizedPreferred) {
        return locale.localeId;
      }
    }
    final langPrefix = normalizedPreferred.split('_').first;
    for (final locale in deviceLocales) {
      if (locale.localeId.replaceAll('-', '_').toLowerCase().startsWith(langPrefix)) {
        return locale.localeId;
      }
    }
    return preferredLocaleId;
  }

  Future<void> startListening({
    required String localeId,
    required void Function(String recognizedWords, bool isFinal, double confidence) onResult,
    void Function(double level)? onSoundLevelChange,
  }) async {
    if (!_isInitialized) {
      throw StateError('SpeechToTextService must be initialized before listening.');
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(
          result.recognizedWords.trim(),
          result.finalResult,
          result.hasConfidenceRating ? result.confidence : 1.0,
        );
      },
      localeId: localeId,
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    if (_speech.isListening) {
      _speech.cancel();
    }
  }

  static Duration estimateCueDuration(String text) {
    final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final seconds = (wordCount * 0.45).clamp(2.0, 8.0);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  static String formatSrtTimestamp(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = safe.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$millis';
  }

  static String buildSrt(List<CaptionCue> cues) {
    if (cues.isEmpty) return '';
    final sorted = List<CaptionCue>.from(cues)
      ..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    for (var i = 0; i < sorted.length; i++) {
      final cue = sorted[i];
      buffer.writeln(i + 1);
      buffer.writeln('${formatSrtTimestamp(cue.start)} --> ${formatSrtTimestamp(cue.end)}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}
