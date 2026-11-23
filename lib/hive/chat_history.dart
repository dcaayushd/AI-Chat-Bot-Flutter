import 'package:hive_flutter/hive_flutter.dart';

part 'chat_history.g.dart';

@HiveType(typeId: 0)
class ChatHistory extends HiveObject {
  @HiveField(0)
  final String chatId;

  @HiveField(1)
  final String prompt;

  @HiveField(2)
  final String response;

  @HiveField(3)
  final List<String> imagesUrls;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final String? title;

  @HiveField(6, defaultValue: false)
  final bool isPinned;

  @HiveField(7)
  final List<Map>? transcript;

  @HiveField(8)
  final String? mode;

  @HiveField(9)
  final Map? options;

  ChatHistory({
    required this.chatId,
    required this.prompt,
    required this.response,
    required this.imagesUrls,
    required this.timestamp,
    this.title,
    this.isPinned = false,
    this.transcript,
    this.mode,
    this.options,
  });

  String get displayTitle => formatTitle(title ?? prompt);

  static String formatTitle(String text) {
    final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? 'Conversation' : value;
  }

  ChatHistory withDetails({
    String? title,
    bool? isPinned,
    Map? options,
    List<Map>? transcript,
  }) => ChatHistory(
    chatId: chatId,
    prompt: prompt,
    response: response,
    imagesUrls: imagesUrls,
    timestamp: timestamp,
    title: title ?? this.title,
    isPinned: isPinned ?? this.isPinned,
    transcript: transcript ?? this.transcript,
    mode: mode,
    options: options ?? this.options,
  );
}
