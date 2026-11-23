import 'dart:convert';

import 'package:chatbotapp/apis/gemini_config.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads a valid key and model from the generated .env asset', () async {
    final config = await GeminiConfig.load(
      bundle: _ConfigBundle(
        '{"API_KEY":"your_google_ai_api_key","GEMINI_API_KEY":" local-test-key ","GEMINI_MODEL":" test-model "}',
      ),
    );
    final override = GeminiConfig.modelOverride.trim();
    expect(config.model, override.isEmpty ? 'test-model' : override);
    final compiledKey = GeminiConfig.developmentKey;
    expect(config.apiKey, compiledKey.isEmpty ? 'local-test-key' : compiledKey);
  });

  test(
    'uses the remaining configuration when the asset is missing or invalid',
    () async {
      for (final contents in [
        null,
        '{broken',
        '[]',
        '{"GEMINI_MODEL": 1,"API_KEY":false}',
      ]) {
        final config = await GeminiConfig.load(bundle: _ConfigBundle(contents));
        final override = GeminiConfig.modelOverride.trim();
        expect(
          config.model,
          override.isEmpty ? Constants.geminiModel : override,
        );
        expect(config.apiKey, GeminiConfig.developmentKey);
      }
    },
  );
}

class _ConfigBundle extends CachingAssetBundle {
  _ConfigBundle(this.contents);

  final String? contents;

  @override
  Future<ByteData> load(String key) async {
    final text = contents;
    if (text == null) throw FlutterError('File missing');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}
