import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  bool _isAvailable = false;
  bool _isListening = false;
  bool _initialized = false;
  String _transcript = '';
  String _error = '';
  double _soundLevel = 0;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  bool get initialized => _initialized;
  String get transcript => _transcript;
  String get error => _error;
  double get soundLevel => _soundLevel;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    try {
      _isAvailable = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );
    } catch (_) {
      _isAvailable = false;
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> startListening() async {
    await ensureInitialized();
    if (!_isAvailable || _isListening) {
      return;
    }

    _error = '';
    _transcript = '';
    _soundLevel = 0;

    await _speech.listen(
      onResult: _handleResult,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      onSoundLevelChange: _handleSoundLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );

    _isListening = true;
    notifyListeners();
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    await _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
    }
    _isListening = false;
    _transcript = '';
    _soundLevel = 0;
    notifyListeners();
  }

  void clearTranscript() {
    _transcript = '';
    _error = '';
    _soundLevel = 0;
    notifyListeners();
  }

  void _handleStatus(String status) {
    final isActive = status == 'listening';
    if (!isActive) {
      _soundLevel = 0;
    }
    _isListening = isActive;
    notifyListeners();
  }

  void _handleResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords;
    notifyListeners();
  }

  void _handleError(SpeechRecognitionError error) {
    _error = _mapError(error.errorMsg);
    _isListening = false;
    _soundLevel = 0;
    notifyListeners();
  }

  void _handleSoundLevel(double level) {
    _soundLevel = level;
    notifyListeners();
  }

  String _mapError(String error) {
    switch (error) {
      case 'error_permission':
      case 'error_permission_denied':
        return 'Microphone permission was denied.';
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'No speech detected.';
      case 'error_network':
      case 'error_network_timeout':
        return 'Voice input needs a stable connection.';
      default:
        return 'Voice input is unavailable right now.';
    }
  }
}
