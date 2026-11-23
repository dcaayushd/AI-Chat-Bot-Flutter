import 'dart:typed_data';

import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/legacy_chat_storage_stub.dart'
    if (dart.library.io) 'package:chatbotapp/hive/legacy_chat_storage_io.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

class ChatRepository {
  static const _imagePrefix = 'attachment:';

  static Future<void> initialize() async {
    await Hive.initFlutter(Constants.geminiDB);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatHistoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(UserModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SettingsAdapter());
    await Future.wait([
      Hive.openBox<ChatHistory>(Constants.chatHistoryBox),
      Hive.openBox<UserModel>(Constants.userBox),
      Hive.openBox<Settings>(Constants.settingsBox),
      Hive.openLazyBox<Map>(Constants.chatImagesBox),
    ]);
  }

  LazyBox<Map> get _images => Hive.lazyBox<Map>(Constants.chatImagesBox);

  String? get _storageDirectory {
    final file = Boxes.getChatHistory().path;
    return file == null ? null : p.dirname(file);
  }

  String imageKey(String chatId, String imageId) =>
      '$_imagePrefix$chatId:$imageId';

  ChatHistory? getChat(String chatId) => Boxes.getChatHistory().get(chatId);

  Future<List<Message>> loadMessages(ChatHistory chat) async {
    final transcript = chat.transcript;
    if (transcript != null) {
      return _decodeMessages(transcript);
    }

    final name = Constants.chatMessagesBox + chat.chatId;
    if (!Hive.isBoxOpen(name) && !await Hive.boxExists(name)) return [];
    final box = await Hive.openBox(name);
    return _decodeMessages(box.values);
  }

  List<Message> _decodeMessages(Iterable<dynamic> stored) =>
      stored.whereType<Map>().map(Message.tryFromMap).nonNulls.toList();

  Future<ChatImage?> loadImage(String chatId, String reference) async {
    try {
      if (reference.startsWith(_imagePrefix)) {
        if (!reference.startsWith(imageKey(chatId, ''))) return null;
        final record = await _images.get(reference);
        if (record case {
          'name': final String name,
          'bytes': final Uint8List bytes,
        }) {
          return ChatImage.fromBytes(name, bytes);
        }
        return null;
      }
      final bytes = await readLegacyChatImage(
        _storageDirectory,
        chatId,
        reference,
      );
      return bytes == null
          ? null
          : ChatImage.fromBytes(p.basename(reference), bytes);
    } on ChatException {
      return null;
    }
  }

  Future<void> save({
    required String chatId,
    required List<Message> messages,
    required ChatMode mode,
    required Map<String, ChatImage> newImages,
  }) async {
    final imageMaps = newImages.map(
      (key, image) => MapEntry(key, image.toMap()),
    );
    final newKeys = imageMaps.keys
        .where((key) => !_images.containsKey(key))
        .toList();
    final history = Boxes.getChatHistory();
    try {
      if (imageMaps.isNotEmpty) await _images.putAll(imageMaps);
      final existing = history.get(chatId);
      final firstPrompt = messages.firstWhere(
        (message) => message.role == Role.user,
      );
      final latest = messages.last;
      final allImageKeys = messages
          .where((message) => message.role == Role.user)
          .expand((message) => message.imagesUrls)
          .toSet();

      // The transcript and its list entry share a single Hive record.
      await history.put(
        chatId,
        ChatHistory(
          chatId: chatId,
          prompt: firstPrompt.text,
          response: latest.text,
          timestamp: DateTime.now(),
          imagesUrls: allImageKeys.toList(),
          title: existing?.title,
          isPinned: existing?.isPinned ?? false,
          transcript: messages.map((message) => message.toMap()).toList(),
          mode: mode.name,
        ),
      );
    } catch (_) {
      if (newKeys.isNotEmpty) {
        try {
          await _images.deleteAll(newKeys);
        } catch (_) {
          // A later conversation deletion also removes unreferenced images.
        }
      }
      rethrow;
    }
  }

  Future<List<ChatHistory>> search(
    List<ChatHistory> chats,
    String query,
  ) async {
    final results = <ChatHistory>[];
    for (final chat in chats) {
      if (chat.displayTitle.toLowerCase().contains(query) ||
          chat.prompt.toLowerCase().contains(query) ||
          chat.response.toLowerCase().contains(query)) {
        results.add(chat);
        continue;
      }
      final transcript = chat.transcript;
      final matches = transcript == null
          ? (await loadMessages(chat))
                .any((m) => m.text.toLowerCase().contains(query))
          : transcript.any(
              (map) => switch (map['message']) {
                final String text => text.toLowerCase().contains(query),
                _ => false,
              },
            );
      if (matches) results.add(chat);
    }
    return results;
  }

  Future<void> rename(String chatId, String title) async {
    final name = title.trim();
    if (name.isEmpty) throw const ChatException('Enter a conversation name.');
    final chat = getChat(chatId);
    if (chat != null) {
      await Boxes.getChatHistory().put(chatId, chat.withDetails(title: name));
    }
  }

  Future<void> togglePin(String chatId) async {
    final chat = getChat(chatId);
    if (chat != null) {
      await Boxes.getChatHistory().put(
        chatId,
        chat.withDetails(isPinned: !chat.isPinned),
      );
    }
  }

  Future<void> delete(String chatId) async {
    final history = Boxes.getChatHistory();
    final chat = history.get(chatId);
    if (chat == null) return;
    final messages = await loadMessages(chat);
    final legacyBox = Constants.chatMessagesBox + chatId;
    if (Hive.isBoxOpen(legacyBox) || await Hive.boxExists(legacyBox)) {
      await Hive.deleteBoxFromDisk(legacyBox);
    }
    final prefix = imageKey(chatId, '');
    final mediaKeys = _images.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList();
    if (mediaKeys.isNotEmpty) await _images.deleteAll(mediaKeys);
    if (messages.any(
          (message) =>
              message.imagesUrls.any((key) => !key.startsWith(_imagePrefix)),
        ) ||
        chat.imagesUrls.any((key) => !key.startsWith(_imagePrefix))) {
      await deleteLegacyChatImages(_storageDirectory, chatId);
    }
    await history.delete(chatId);
  }

  Future<void> clear() async {
    final chatIds = Boxes.getChatHistory().keys.whereType<String>().toList();
    for (final chatId in chatIds) {
      await delete(chatId);
    }
    final storageDirectory = _storageDirectory;
    for (final box in await legacyMessageBoxes(storageDirectory)) {
      await Hive.deleteBoxFromDisk(box);
    }
    await clearLegacyChatImages(storageDirectory);
    await _images.clear();
  }
}
