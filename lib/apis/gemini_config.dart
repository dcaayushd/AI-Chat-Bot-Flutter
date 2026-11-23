import 'dart:convert';

import 'package:chatbotapp/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GeminiConfig {
  const GeminiConfig._({required this.apiKey, required this.model});

  static const modelOverride = String.fromEnvironment('GEMINI_MODEL');
  static const _asset = 'assets/gemini_config.json';
  static final _invalidKeyCharacters = RegExp(r'[\s\x00-\x1f\x7f]');
  static const _keyNames = ['API_KEY', 'GEMINI_API_KEY', 'GOOGLE_API_KEY'];
  static const _buildKeys = [
    String.fromEnvironment('API_KEY'),
    String.fromEnvironment('GEMINI_API_KEY'),
    String.fromEnvironment('GOOGLE_API_KEY'),
  ];

  final String apiKey;
  final String model;

  static String get developmentKey => _firstKey(_buildKeys) ?? '';

  static Future<GeminiConfig> load({AssetBundle? bundle}) async {
    final local = kDebugMode
        ? await _localSettings(bundle ?? rootBundle)
        : const <String, String>{};
    final override = modelOverride.trim();
    final localModel = local['GEMINI_MODEL']?.trim() ?? '';
    return GeminiConfig._(
      apiKey:
          _firstKey([..._buildKeys, for (final key in _keyNames) local[key]]) ??
          '',
      model: override.isNotEmpty
          ? override
          : (localModel.isEmpty ? Constants.geminiModel : localModel),
    );
  }

  static String? normalizeKey(String input) {
    final value = input.trim();
    return value.isEmpty ||
            value == 'your_google_ai_api_key' ||
            _invalidKeyCharacters.hasMatch(value)
        ? null
        : value;
  }

  static String? _firstKey(Iterable<Object?> candidates) =>
      candidates.whereType<String>().map(normalizeKey).nonNulls.firstOrNull;

  static Future<Map<String, String>> _localSettings(AssetBundle bundle) async {
    try {
      final decoded = jsonDecode(await bundle.loadString(_asset));
      if (decoded is Map<String, dynamic>) {
        return {
          for (final entry in decoded.entries)
            if (entry.value is String) entry.key: entry.value as String,
        };
      }
    } on FlutterError {
      // The app can still accept a session key when the local asset is missing.
    } on FormatException {
      // Ignore a malformed asset and use the remaining configuration sources.
    }
    return const {};
  }
}
