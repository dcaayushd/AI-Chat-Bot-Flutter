import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:chatbotapp/apis/gemini_config.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';

class GeminiTurn {
  const GeminiTurn(this.role, this.text, [this.images = const []]);

  final Role role;
  final String text;
  final List<ChatImage> images;
}

class GeminiChunk {
  const GeminiChunk({this.text = '', this.truncated = false});

  final String text;
  final bool truncated;
}

class GeminiClient {
  GeminiClient({
    http.Client? httpClient,
    String model = GeminiConfig.modelOverride,
    Duration inactivityTimeout = const Duration(seconds: 60),
  }) : _http = httpClient ?? http.Client(),
       _timeout = inactivityTimeout,
       model = _normalizeModel(model);

  static const _host = 'generativelanguage.googleapis.com';
  static const _errorReadTimeout = Duration(seconds: 2);
  static const _maximumErrorBytes = 16 * 1024;
  static const _blockedReasons = {
    'SAFETY',
    'RECITATION',
    'BLOCKLIST',
    'PROHIBITED_CONTENT',
    'SPII',
    'IMAGE_SAFETY',
    'IMAGE_PROHIBITED_CONTENT',
    'MODEL_ARMOR',
  };

  final http.Client _http;
  final Duration _timeout;
  final String model;

  static String _normalizeModel(String model) {
    final name = model.trim();
    if (name.isEmpty) return Constants.geminiModel;
    return name.startsWith('models/') ? name.substring(7) : name;
  }

  Stream<GeminiChunk> streamReply({
    required String apiKey,
    required ChatMode mode,
    required List<GeminiTurn> turns,
    required Future<void> abort,
  }) async* {
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
      throw const ChatException('Check the GEMINI_MODEL setting.');
    }
    final uri = Uri.https(
      _host,
      '/v1beta/models/$model:streamGenerateContent',
      {'alt': 'sse'},
    );
    final request = http.AbortableRequest('POST', uri, abortTrigger: abort)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      })
      ..body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': Constants.assistantSystemInstruction},
            if (mode.instruction.isNotEmpty) {'text': mode.instruction},
          ],
        },
        'contents': _contents(turns),
        'generationConfig': {'maxOutputTokens': 8192},
      });

    final response = await _http.send(request).timeout(_timeout);
    if (response.statusCode != 200) {
      final status = response.statusCode;
      var keyProblem = false;
      if (status == 400 || status == 403) {
        keyProblem = await _readKeyError(response.stream);
      } else {
        await response.stream.listen(null).cancel();
      }
      throw ChatException(_httpError(status, keyProblem: keyProblem));
    }

    await for (final event in _eventData(response.stream).timeout(_timeout)) {
      if (event == '[DONE]') return;
      final payload = _decodeJson(event);
      if (payload is! Map<String, dynamic>) {
        throw const ChatException('Gemini returned an invalid response.');
      }
      final error = payload['error'];
      if (error case {'code': final int status}) {
        throw ChatException(
          _httpError(status, keyProblem: _hasKeyError(error)),
        );
      }
      if (payload['promptFeedback'] case {'blockReason': final String reason}
          when reason != 'BLOCK_REASON_UNSPECIFIED') {
        throw const ChatException(
          'Gemini blocked this prompt. Try rephrasing it.',
        );
      }
      if (payload['candidates'] case [final Map candidate, ...]) {
        final finish = candidate['finishReason'];
        if (_blockedReasons.contains(finish)) {
          throw const ChatException(
            'Gemini stopped this reply. Try rephrasing the prompt.',
          );
        }
        final parts = switch (candidate['content']) {
          {'parts': final List parts} => parts,
          _ => const [],
        };
        final text = StringBuffer();
        for (final part in parts) {
          if (part case {'text': final String delta}
              when part['thought'] != true) {
            text.write(delta);
          }
        }
        if (text.isNotEmpty || finish == 'MAX_TOKENS') {
          yield GeminiChunk(
            text: text.toString(),
            truncated: finish == 'MAX_TOKENS',
          );
        }
        if (finish == 'STOP' || finish == 'MAX_TOKENS') return;
        if (finish != null && finish != 'FINISH_REASON_UNSPECIFIED') break;
      }
    }
    throw const ChatException('Gemini ended the reply early. Try again.');
  }

  List<Map<String, Object>> _contents(List<GeminiTurn> turns) {
    final contents = <Map<String, Object>>[];
    Role? previousRole;
    var parts = <Map<String, Object>>[];
    for (final turn in turns) {
      if (turn.role != previousRole) {
        parts = [];
        contents.add({
          'role': turn.role == Role.user ? 'user' : 'model',
          'parts': parts,
        });
        previousRole = turn.role;
      }
      parts.add({'text': turn.text});
      for (final image in turn.images) {
        parts.add({
          'inlineData': {
            'mimeType': image.mimeType,
            'data': base64Encode(image.bytes),
          },
        });
      }
    }
    return contents;
  }

  Stream<String> _eventData(Stream<List<int>> bytes) async* {
    final lines = <String>[];
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (lines.isNotEmpty) {
          yield lines.join('\n');
          lines.clear();
        }
      } else if (line.startsWith('data:')) {
        final data = line.substring(5);
        lines.add(data.startsWith(' ') ? data.substring(1) : data);
      }
    }
    if (lines.isNotEmpty) yield lines.join('\n');
  }

  Object? _decodeJson(String data) {
    try {
      return jsonDecode(data);
    } on FormatException {
      return null;
    }
  }

  Future<bool> _readKeyError(Stream<List<int>> body) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in body.timeout(_errorReadTimeout)) {
        if (bytes.length + chunk.length > _maximumErrorBytes) return false;
        bytes.add(chunk);
      }
      if (_decodeJson(utf8.decode(bytes.takeBytes())) case {
        'error': final Object error,
      }) {
        return _hasKeyError(error);
      }
    } on Exception {
      // The response body may be missing or contain malformed data.
    }
    return false;
  }

  bool _hasKeyError(Object error) {
    if (error case {'details': final List details}) {
      return details.any(
        (detail) => switch (detail) {
          {'reason': final String reason} => reason.startsWith('API_KEY_'),
          _ => false,
        },
      );
    }
    return false;
  }

  String _httpError(int status, {required bool keyProblem}) {
    if (keyProblem || status == 401) {
      return 'Gemini rejected the API key. Check your key in .env or Settings.';
    }
    return switch (status) {
      400 =>
        'Gemini rejected the request. Check the model and any attachments.',
      402 => 'Gemini billing needs attention in Google AI Studio.',
      403 =>
        'Gemini denied access. Check your project and API key restrictions.',
      404 =>
        'This Gemini model is unavailable. Check the GEMINI_MODEL setting.',
      408 || 504 => 'Gemini took too long to respond. Try again.',
      413 => 'The request is too large. Try fewer images or a shorter message.',
      429 =>
        'Gemini’s rate or quota limit was reached. Wait before trying again.',
      >= 500 => 'Gemini is temporarily unavailable. Try again shortly.',
      _ => 'Gemini could not complete this request. Try again.',
    };
  }

  void close() => _http.close();
}
