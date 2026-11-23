class ReplyBookmark {
  const ReplyBookmark({
    required this.chatId,
    required this.messageId,
    required this.chatTitle,
    required this.text,
    required this.savedAt,
  });

  final String chatId;
  final String messageId;
  final String chatTitle;
  final String text;
  final DateTime savedAt;
}
