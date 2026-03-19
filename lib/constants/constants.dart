class Constants {
  static const String appName = 'AI Chatbot';
  static const String appTitle = 'AI Chatbot';
  static const String appDescription = 'Fast Gemini chat';
  static const String chatHistoryBox = 'chat_history';
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings';

  static const String chatMessagesBox = 'chat_messages_';

  static const String geminiDB = 'gemini.db';
  static const String geminiTextModel = 'gemini-2.5-flash';
  static const String geminiVisionModel = 'gemini-2.5-flash';
  static const String assistantSystemInstruction =
      'You are AI Chatbot, a helpful assistant. Give clear, accurate, and concise answers. '
      'Use short sections or bullets when it improves readability. '
      'For code, provide runnable examples and mention important assumptions briefly. '
      'For images, describe what is visible before giving conclusions. '
      'If the request is unclear, ask one short clarifying question instead of guessing.';

  static const List<String> starterPrompts = [
    'Summarize this',
    'Plan my day',
    'Draft a reply',
    'Explain a concept',
    'Improve writing',
    'Analyze an image',
  ];
}
