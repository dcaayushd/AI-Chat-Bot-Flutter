import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  bool _isAvailable = false;
  bool _isListening = false;
  bool _starting = false;
  bool _disposed = false;
  int _attempt = 0;
  String _transcript = '';
  String _error = '';

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  bool get isStarting => _starting;
  String get transcript => _transcript;
  String get error => _error;

  Future<void> _ensureInitialized() async {
    if (_isAvailable) return;

    try {
      _isAvailable = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        options: [SpeechToText.androidNoBluetooth],
      );
    } catch (_) {
      _isAvailable = false;
    }

    _notify();
  }

  Future<void> startListening() async {
    if (_starting || _isListening || _disposed) return;
    final attempt = ++_attempt;
    _starting = true;
    _notify();
    try {
      await _ensureInitialized();
      if (!_isAvailable || _disposed || attempt != _attempt) return;

      await _speech.listen(
        onResult: (result) {
          if (attempt == _attempt) _handleResult(result);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      if (_disposed || attempt != _attempt) {
        await cancelListening();
        return;
      }
      _isListening = _speech.isListening;
    } finally {
      _starting = false;
      _notify();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    await _speech.stop();
    _isListening = false;
    _notify();
  }

  Future<void> cancelListening() async {
    _attempt++;
    try {
      if (_isListening || _speech.isListening) await _speech.cancel();
    } catch (_) {
      _error = 'Could not stop dictation.';
    } finally {
      _isListening = false;
      _transcript = '';
      _notify();
    }
  }

  void clearTranscript() {
    _transcript = '';
    _error = '';
    _notify();
  }

  void _handleStatus(String status) {
    _isListening = status == SpeechToText.listeningStatus;
    _notify();
  }

  void _handleResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords;
    _notify();
  }

  void _handleError(SpeechRecognitionError error) {
    _error = _mapError(error.errorMsg);
    _isListening = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_isListening || _starting) unawaited(cancelListening());
    super.dispose();
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
