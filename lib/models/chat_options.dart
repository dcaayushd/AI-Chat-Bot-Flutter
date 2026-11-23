import 'package:chatbotapp/utilities/chat_error_formatter.dart';

enum ReplyLength {
  concise('Concise', 'Lead with the answer and keep the response brief.', 4096),
  balanced('Balanced', '', 8192),
  detailed(
    'Detailed',
    'Provide a thorough response, with examples and important tradeoffs when useful.',
    16384,
  );

  const ReplyLength(this.label, this.instruction, this.maxOutputTokens);

  final String label;
  final String instruction;
  final int maxOutputTokens;
}

class ChatOptions {
  const ChatOptions({
    this.length = ReplyLength.balanced,
    this.instructions = '',
  });

  static const maxInstructionsLength = 2000;

  final ReplyLength length;
  final String instructions;

  factory ChatOptions.fromMap(Map? map) {
    final rawInstructions = map?['instructions'];
    return ChatOptions(
      length: ReplyLength.values.firstWhere(
        (length) => length.name == map?['length'],
        orElse: () => ReplyLength.balanced,
      ),
      instructions:
          rawInstructions is String &&
              rawInstructions.length <= maxInstructionsLength
          ? rawInstructions.trim()
          : '',
    );
  }

  ChatOptions normalized() {
    final value = instructions.trim();
    if (value.length > maxInstructionsLength) {
      throw const ChatException(
        'Keep chat instructions under 2,000 characters.',
      );
    }
    return ChatOptions(length: length, instructions: value);
  }

  Map<String, String> toMap() => {
    'length': length.name,
    'instructions': instructions,
  };

  @override
  bool operator ==(Object other) =>
      other is ChatOptions &&
      other.length == length &&
      other.instructions == instructions;

  @override
  int get hashCode => Object.hash(length, instructions);
}
