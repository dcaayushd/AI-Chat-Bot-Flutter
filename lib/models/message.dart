enum Role { user, assistant }

enum ReplyStatus {
  complete,
  stopped,
  interrupted,
  truncated;

  static ReplyStatus fromName(Object? name) => values.firstWhere(
    (status) => status.name == name,
    orElse: () => complete,
  );
}

class ReplyRevision {
  const ReplyRevision({
    required this.text,
    required this.timeSent,
    required this.status,
    this.contextLimited = false,
  });

  final String text;
  final DateTime timeSent;
  final ReplyStatus status;
  final bool contextLimited;

  static ReplyRevision? tryFromMap(Map map) {
    if (map case {'text': final String text, 'time': final String rawTime}) {
      final time = DateTime.tryParse(rawTime);
      if (time != null && text.trim().isNotEmpty) {
        return ReplyRevision(
          text: text,
          timeSent: time,
          status: ReplyStatus.fromName(map['status']),
          contextLimited: map['contextLimited'] == true,
        );
      }
    }
    return null;
  }

  Map<String, Object> toMap() => {
    'text': text,
    'time': timeSent.toIso8601String(),
    'status': status.name,
    if (contextLimited) 'contextLimited': true,
  };
}

class Message {
  Message({
    required this.messageId,
    required this.chatId,
    required this.role,
    required this.text,
    required this.timeSent,
    List<String> imagesUrls = const [],
    List<String> documentRefs = const [],
    this.status = ReplyStatus.complete,
    this.contextLimited = false,
    List<ReplyRevision> previousReplies = const [],
  }) : imagesUrls = List.unmodifiable(imagesUrls),
       documentRefs = List.unmodifiable(documentRefs),
       previousReplies = List.unmodifiable(
         previousReplies.take(maxPreviousReplies),
       );

  static const maxPreviousReplies = 4;

  final String messageId;
  final String chatId;
  final Role role;
  final String text;
  final List<String> imagesUrls;
  final List<String> documentRefs;
  final DateTime timeSent;
  final ReplyStatus status;
  final bool contextLimited;
  final List<ReplyRevision> previousReplies;

  Iterable<String> get attachmentRefs => imagesUrls.followedBy(documentRefs);

  factory Message.fromMap(Map<dynamic, dynamic> map) =>
      tryFromMap(map) ?? (throw const FormatException('Invalid saved message'));

  static List<String> _references(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

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
        imagesUrls: _references(map['imagesUrls']),
        documentRefs: _references(map['documentRefs']),
        timeSent: sentAt,
        status: ReplyStatus.fromName(map['status']),
        contextLimited: map['contextLimited'] == true,
        previousReplies: switch (map['previousReplies']) {
          final List revisions =>
            revisions
                .whereType<Map>()
                .map(ReplyRevision.tryFromMap)
                .nonNulls
                .take(maxPreviousReplies)
                .toList(),
          _ => const [],
        },
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
    if (documentRefs.isNotEmpty) 'documentRefs': documentRefs,
    'timeSent': timeSent.toIso8601String(),
    'status': status.name,
    if (contextLimited) 'contextLimited': true,
    if (previousReplies.isNotEmpty)
      'previousReplies': previousReplies
          .map((revision) => revision.toMap())
          .toList(),
  };

  ReplyRevision get revision => ReplyRevision(
    text: text,
    timeSent: timeSent,
    status: status,
    contextLimited: contextLimited,
  );

  Message selectRevision(ReplyRevision version) => copyWith(
    text: version.text,
    timeSent: version.timeSent,
    status: version.status,
    contextLimited: version.contextLimited,
    previousReplies: [
      revision,
      ...previousReplies.where((old) => old != version),
    ],
  );

  Message copyWith({
    String? messageId,
    String? chatId,
    String? text,
    DateTime? timeSent,
    List<String>? imagesUrls,
    List<String>? documentRefs,
    ReplyStatus? status,
    bool? contextLimited,
    List<ReplyRevision>? previousReplies,
  }) => Message(
    messageId: messageId ?? this.messageId,
    chatId: chatId ?? this.chatId,
    role: role,
    text: text ?? this.text,
    timeSent: timeSent ?? this.timeSent,
    imagesUrls: imagesUrls ?? this.imagesUrls,
    documentRefs: documentRefs ?? this.documentRefs,
    status: status ?? this.status,
    contextLimited: contextLimited ?? this.contextLimited,
    previousReplies: previousReplies ?? this.previousReplies,
  );
}
