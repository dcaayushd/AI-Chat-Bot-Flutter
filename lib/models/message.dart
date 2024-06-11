class Message {
  String messageId;
  String chatId;
  Role role;
  StringBuffer message;
  List<String> imageUrls;
  DateTime timeSent;

  //Constructor
  Message({
    required this.messageId,
    required this.chatId,
    required this.role,
    required this.message,
    required this.imageUrls,
    required this.timeSent,
  });

  //To Map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'messageId': messageId,
      'chatId': chatId,
      'role': role.index,
      'message': message.toString(),
      'imageUrls': imageUrls,
      'timeSent': timeSent.toIso8601String(),
    };
  }

  // From Map
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      messageId: map['messageId'],
      chatId: map['chatId'],
      role: Role.values[map['roles']],
      message: StringBuffer(map['message']),
      imageUrls: List<String>.from(map['imageUrls']),
      timeSent: DateTime.parse(map['timeSent']),
    );
  }

  // Copy With
  Message copyWith({
    String? messageId,
    String? chatId,
    Role? role,
    StringBuffer? message,
    List<String>? imageUrls,
    DateTime? timeSent,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      message: message ?? this.message,
      imageUrls: imageUrls ?? this.imageUrls,
      timeSent: timeSent ?? this.timeSent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Message && other.messageId == messageId;
  }

  @override
  int get hashCode {
    return messageId.hashCode;
  }
}

enum Role {
  user,
  assistant,
}
