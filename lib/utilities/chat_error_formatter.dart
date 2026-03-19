String formatChatError(Object error) {
  if (error case StateError(:final message)) {
    return message;
  }

  final text = error.toString().toLowerCase();

  if (text.contains('operation timed out') ||
      text.contains('timeoutexception')) {
    return 'Request timed out. Check your connection and try again.';
  }

  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed')) {
    return 'Could not reach Gemini. Check your network and try again.';
  }

  if (text.contains('api key')) {
    return 'Add your Gemini API key to continue.';
  }

  return 'Something went wrong. Please try again.';
}

bool shouldRetryRequest(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('api key') ||
      text.contains('permission') ||
      text.contains('not found')) {
    return false;
  }

  return text.contains('operation timed out') ||
      text.contains('timeoutexception') ||
      text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed');
}
