import 'dart:convert';
import 'dart:io';

final _setting = RegExp(
  r'''^\s*(?:export\s+)?(API_KEY|GEMINI_API_KEY|GOOGLE_API_KEY|GEMINI_MODEL)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^#]*))\s*(?:#.*)?$''',
);

void main(List<String> args) {
  const outputFlag = '--output=';
  final outputPath = args
      .singleWhere((argument) => argument.startsWith(outputFlag))
      .substring(outputFlag.length);
  final isDebug = Platform.environment['FLUTTER_BUILD_MODE'] == 'debug';
  final settings = <String, String>{};
  final env = File('.env');

  if (isDebug && env.existsSync()) {
    for (final line in env.readAsLinesSync()) {
      final assignment = _setting.firstMatch(line);
      if (assignment == null) continue;
      final value = assignment[2] ?? assignment[3] ?? assignment[4]!;
      settings[assignment[1]!] = value.trim();
    }
  }

  File(outputPath).writeAsStringSync(jsonEncode(settings));

  // Flutter resolves the transformer dependencies against the project root.
  final inputs =
      isDebug ? 'bin/gemini_env_asset.dart .env' : 'bin/gemini_env_asset.dart';
  File('$outputPath.d')
      .writeAsStringSync('assets/gemini_config.json: $inputs\n');
}
