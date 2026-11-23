import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';

class GeminiContext {
  const GeminiContext(this.turns, {required this.limited});

  static const maxTextLength = 80000;
  static const maxMessages = 24;

  final List<GeminiTurn> turns;
  final bool limited;

  static Future<GeminiContext> build({
    required List<Message> messages,
    required int promptIndex,
    required Future<ChatAttachment?> Function(String, String) loadAttachment,
    required bool Function() stopped,
    List<GeminiTurn> suffix = const [],
  }) async {
    final turns = <GeminiTurn>[];
    var limited = false;
    var remainingText =
        maxTextLength -
        suffix.fold(0, (total, turn) => total + turn.text.length);
    var remainingBytes = ChatAttachment.maxRequestBytes;
    final first = (promptIndex + 1 - maxMessages + suffix.length).clamp(
      0,
      promptIndex,
    );

    for (var index = promptIndex; index >= first && !stopped(); index--) {
      final message = messages[index];
      final current = index == promptIndex;
      if (message.text.length > remainingText) {
        if (current)
          throw const ChatException('This prompt exceeds the request budget.');
        break;
      }
      remainingText -= message.text.length;
      final attachments = <ChatAttachment>[];
      if (message.role == Role.user) {
        for (final reference in message.attachmentRefs) {
          if (stopped()) break;
          if (remainingBytes == 0 && !current) {
            limited = true;
            break;
          }
          final attachment = await loadAttachment(message.chatId, reference);
          if (stopped()) break;
          if (attachment == null) {
            if (current) {
              throw const ChatException(
                'An attachment is unavailable. Send the prompt with the file again.',
              );
            }
            limited = true;
            continue;
          }
          final textLength = attachment is ChatDocument
              ? attachment.text?.length ?? 0
              : 0;
          if (attachment.bytes.length > remainingBytes ||
              textLength > remainingText) {
            if (current) {
              throw const ChatException(
                'This prompt and its attachments exceed the request budget.',
              );
            }
            limited = true;
            continue;
          }
          attachments.add(attachment);
          remainingBytes -= attachment.bytes.length;
          remainingText -= textLength;
        }
      }
      turns.add(GeminiTurn(message.role, message.text, attachments));
    }

    final context = turns.reversed
        .skipWhile((turn) => turn.role == Role.assistant)
        .toList();
    return GeminiContext([
      ...context,
      ...suffix,
    ], limited: limited || context.length < promptIndex + 1);
  }
}
