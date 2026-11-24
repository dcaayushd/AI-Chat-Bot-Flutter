import 'dart:typed_data';

import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/legacy_chat_storage_stub.dart'
    if (dart.library.io) 'package:chatbotapp/hive/legacy_chat_storage_io.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/models/chat_archive.dart';
import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/chat_options.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/models/reply_bookmark.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ChatRepository {
  static const _attachmentPrefix = 'attachment:';
  static const _uuid = Uuid();

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
      Hive.openBox<String>(Constants.chatDraftsBox),
      Hive.openBox<Map>(Constants.chatProjectsBox),
    ]);
  }

  LazyBox<Map> get _attachments => Hive.lazyBox<Map>(Constants.chatImagesBox);

  String? get _storageDirectory {
    final file = Boxes.getChatHistory().path;
    return file == null ? null : p.dirname(file);
  }

  String attachmentKey(String chatId, String id) =>
      '$_attachmentPrefix$chatId:$id';

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

  Future<ChatAttachment?> loadAttachment(
    String chatId,
    String reference,
  ) async {
    try {
      if (reference.startsWith(_attachmentPrefix)) {
        if (!reference.startsWith(attachmentKey(chatId, ''))) return null;
        final record = await _attachments.get(reference);
        if (record case {
          'name': final String name,
          'bytes': final Uint8List bytes,
        }) {
          return record['kind'] == 'document'
              ? ChatDocument.fromBytes(name, bytes)
              : ChatImage.fromBytes(name, bytes);
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

  Future<ChatImage?> loadImage(String chatId, String reference) async {
    final attachment = await loadAttachment(chatId, reference);
    return attachment is ChatImage ? attachment : null;
  }

  Future<void> save({
    required String chatId,
    required List<Message> messages,
    required ChatMode mode,
    required ChatOptions options,
    required Map<String, ChatAttachment> newAttachments,
    String? title,
    String? projectId,
  }) async {
    final attachmentMaps = newAttachments.map(
      (key, attachment) => MapEntry(key, attachment.toMap()),
    );
    final newKeys = attachmentMaps.keys
        .where((key) => !_attachments.containsKey(key))
        .toList();
    final history = Boxes.getChatHistory();
    try {
      if (attachmentMaps.isNotEmpty) await _attachments.putAll(attachmentMaps);
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
          title: existing?.title ?? title,
          isPinned: existing?.isPinned ?? false,
          transcript: messages.map((message) => message.toMap()).toList(),
          mode: mode.name,
          options: options.toMap(),
          projectId: projectId,
        ),
      );
    } catch (_) {
      await _discardAttachments(newKeys);
      rethrow;
    }
  }

  Future<List<Message>> saveBranch({
    required String chatId,
    required String title,
    required Iterable<Message> prefix,
    required ChatMode mode,
    required ChatOptions options,
    String? projectId,
  }) => _copyConversation(
    chatId: chatId,
    title: title,
    sourceMessages: prefix,
    mode: mode,
    options: options,
    projectId: projectId,
    resolveAttachment: loadAttachment,
    clearBookmarks: true,
  );

  Future<void> restoreArchive({
    required String chatId,
    required ChatArchive archive,
    String? projectId,
  }) async {
    await _copyConversation(
      chatId: chatId,
      title: archive.title,
      sourceMessages: archive.messages,
      mode: archive.mode,
      options: archive.options,
      projectId: projectId,
      resolveAttachment: (_, reference) async => archive.attachments[reference],
      clearBookmarks: false,
    );
  }

  Future<List<Message>> _copyConversation({
    required String chatId,
    required String title,
    required Iterable<Message> sourceMessages,
    required ChatMode mode,
    required ChatOptions options,
    required String? projectId,
    required Future<ChatAttachment?> Function(String, String) resolveAttachment,
    required bool clearBookmarks,
  }) async {
    final copied = <(String, String), String>{};
    final messages = <Message>[];
    try {
      // Copies own their media. Stage one attachment at a time to bound memory use.
      for (final message in sourceMessages) {
        for (final reference in message.attachmentRefs.toSet()) {
          final source = (message.chatId, reference);
          if (copied.containsKey(source)) continue;
          final attachment = await resolveAttachment(message.chatId, reference);
          if (attachment == null) {
            throw const ChatException(
              'An attachment in this conversation is unavailable.',
            );
          }
          final key = attachmentKey(chatId, _uuid.v4());
          copied[source] = key;
          await _attachments.put(key, attachment.toMap());
        }
        messages.add(
          message.copyWith(
            clearBookmark: clearBookmarks,
            messageId: _uuid.v4(),
            chatId: chatId,
            imagesUrls: [
              for (final key in message.imagesUrls)
                copied[(message.chatId, key)]!,
            ],
            documentRefs: [
              for (final key in message.documentRefs)
                copied[(message.chatId, key)]!,
            ],
          ),
        );
      }
      await save(
        chatId: chatId,
        messages: messages,
        mode: mode,
        options: options,
        newAttachments: const {},
        title: title,
        projectId: projectId,
      );
      return messages;
    } catch (_) {
      await _discardAttachments(copied.values);
      rethrow;
    }
  }

  Future<void> _discardAttachments(Iterable<String> keys) async {
    if (keys.isEmpty) return;
    try {
      await _attachments.deleteAll(keys);
    } catch (_) {
      // Clearing history also removes unreferenced attachments.
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

  Future<void> moveToProject(String chatId, String? projectId) async {
    final chat = getChat(chatId);
    if (chat == null)
      throw const ChatException('This chat is no longer available.');
    if (chat.projectId == projectId) return;
    await Boxes.getChatHistory().put(
      chatId,
      chat.withDetails(projectId: projectId, clearProject: projectId == null),
    );
  }

  List<ReplyBookmark> findBookmarks(Iterable<ChatHistory> chats, String query) {
    final results = <ReplyBookmark>[];
    for (final chat in chats) {
      final title = chat.displayTitle;
      final titleMatches = title.toLowerCase().contains(query);
      for (final entry in chat.transcript ?? const <Map>[]) {
        if (entry['role'] != Role.assistant.index) continue;
        if (entry case {
          'messageId': final String id,
          'message': final String text,
          'bookmarkedAt': final String rawTime,
        }) {
          final time = DateTime.tryParse(rawTime);
          if (time == null ||
              (!titleMatches && !text.toLowerCase().contains(query)))
            continue;
          results.add(
            ReplyBookmark(
              chatId: chat.chatId,
              messageId: id,
              chatTitle: title,
              text: text,
              savedAt: time,
            ),
          );
        }
      }
    }
    return results..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  Future<void> updateTranscript(String chatId, List<Message> messages) async {
    final chat = getChat(chatId);
    if (chat == null)
      throw const ChatException('This chat is no longer available.');
    await Boxes.getChatHistory().put(
      chatId,
      chat.withDetails(
        transcript: messages.map((message) => message.toMap()).toList(),
      ),
    );
  }

  Future<void> saveOptions(String chatId, ChatOptions options) async {
    final chat = getChat(chatId);
    if (chat == null)
      throw const ChatException('This chat is no longer available.');
    await Boxes.getChatHistory().put(
      chatId,
      chat.withDetails(options: options.toMap()),
    );
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
    final prefix = attachmentKey(chatId, '');
    final mediaKeys = _attachments.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList();
    if (mediaKeys.isNotEmpty) await _attachments.deleteAll(mediaKeys);
    if (messages.any(
          (message) => message.imagesUrls.any(
            (key) => !key.startsWith(_attachmentPrefix),
          ),
        ) ||
        chat.imagesUrls.any((key) => !key.startsWith(_attachmentPrefix))) {
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
    await _attachments.clear();
  }
}
