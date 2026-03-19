import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static const String _placeholderApiKey = 'your_google_ai_api_key';
  static const String _dartDefineApiKey = String.fromEnvironment('API_KEY');
  static const List<String> _apiKeyEnvNames = [
    'API_KEY',
    'GEMINI_API_KEY',
    'GOOGLE_API_KEY',
  ];

  static String get apiKey {
    final dartDefineApiKey = _dartDefineApiKey.trim();
    if (dartDefineApiKey.isNotEmpty && dartDefineApiKey != _placeholderApiKey) {
      return dartDefineApiKey;
    }

    if (!dotenv.isInitialized) {
      throw StateError(
        'Environment variables were not loaded. Add a .env file with API_KEY.',
      );
    }

    for (final envName in _apiKeyEnvNames) {
      final value = dotenv.env[envName]?.trim();
      if (value != null && value.isNotEmpty && value != _placeholderApiKey) {
        return value;
      }
    }

    throw StateError(
      'Missing Gemini API key. Replace API_KEY in .env or run with --dart-define=API_KEY=your_key.',
    );
  }

  static bool get isConfigured {
    final dartDefineApiKey = _dartDefineApiKey.trim();
    if (dartDefineApiKey.isNotEmpty && dartDefineApiKey != _placeholderApiKey) {
      return true;
    }

    if (!dotenv.isInitialized) {
      return false;
    }

    for (final envName in _apiKeyEnvNames) {
      final value = dotenv.env[envName]?.trim();
      if (value != null && value.isNotEmpty && value != _placeholderApiKey) {
        return true;
      }
    }

    return false;
  }
}
