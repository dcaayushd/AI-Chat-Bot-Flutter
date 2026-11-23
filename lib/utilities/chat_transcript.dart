import 'package:chatbotapp/models/message.dart';

String transcriptAsMarkdown(String title, Iterable<Message> messages) {
  final output = StringBuffer('# $title\n\n');
  for (final message in messages) {
    final author = message.role == Role.user ? 'You' : 'Gemini';
    final status = switch (message.status) {
      ReplyStatus.complete => '',
      ReplyStatus.stopped => ' (stopped)',
      ReplyStatus.interrupted => ' (interrupted)',
      ReplyStatus.truncated => ' (truncated)',
    };
    output.writeln('## $author$status\n');
    if (message.imagesUrls.isNotEmpty && message.role == Role.user) {
      final count = message.imagesUrls.length;
      output.writeln(
          count == 1 ? '[1 attached image]\n' : '[$count attached images]\n');
    }
    output.writeln(message.text);
    output.writeln();
  }
  return output.toString().trimRight();
}
