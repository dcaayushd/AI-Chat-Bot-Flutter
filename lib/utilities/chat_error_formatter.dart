import 'dart:async';

import 'package:http/http.dart' as http;

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

String formatChatError(Object error) => switch (error) {
      ChatException(:final message) => message,
      TimeoutException() => 'Gemini took too long to respond. Try again.',
      http.ClientException() =>
        'Could not reach Gemini. Check your connection.',
      _ => 'Something went wrong. Please try again.',
    };
