enum Role { user, assistant }

enum ReplyStatus { complete, stopped, interrupted, truncated }

class Message {
  Message({
    required this.messageId,
    required this.chatId,
    required this.role,
    required this.text,
    required this.timeSent,
    List<String> imagesUrls = const [],
    this.status = ReplyStatus.complete,
  }) : imagesUrls = List.unmodifiable(imagesUrls);

  final String messageId;
  final String chatId;
  final Role role;
  final String text;
  final List<String> imagesUrls;
  final DateTime timeSent;
  final ReplyStatus status;

  factory Message.fromMap(Map<dynamic, dynamic> map) =>
      tryFromMap(map) ?? (throw const FormatException('Invalid saved message'));

  static Message? tryFromMap(Map<dynamic, dynamic> map) {
    if (map case {
      'messageId': final String id,
      'chatId': final String chatId,
      'role': final int roleIndex,
      'message': final String text,
      'timeSent': final String rawTime,
    }) {
      final role = Role.values.asMap()[roleIndex];
      final sentAt = DateTime.tryParse(rawTime);
      if (role == null || sentAt == null) return null;
      return Message(
        messageId: id,
        chatId: chatId,
        role: role,
        text: text,
        imagesUrls: switch (map['imagesUrls']) {
          final List images => images.whereType<String>().toList(),
          _ => const [],
        },
        timeSent: sentAt,
        status: ReplyStatus.values.firstWhere(
          (status) => status.name == map['status'],
          orElse: () => ReplyStatus.complete,
        ),
      );
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'chatId': chatId,
    'role': role.index,
    'message': text,
    'imagesUrls': imagesUrls,
    'timeSent': timeSent.toIso8601String(),
    'status': status.name,
  };

  Message withReply(String text, {ReplyStatus status = ReplyStatus.complete}) =>
      Message(
        messageId: messageId,
        chatId: chatId,
        role: role,
        text: text,
        imagesUrls: imagesUrls,
        timeSent: timeSent,
        status: status,
      );
}
