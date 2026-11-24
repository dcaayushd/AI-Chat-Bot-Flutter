import 'dart:convert';
import 'dart:typed_data';

import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/chat_options.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';

class ChatArchive {
  ChatArchive._({
    required this.title,
    required this.mode,
    required this.options,
    required this.messages,
    required this.attachments,
  });

  static const _format = 'chatbotapp.conversation';
  static const _version = 1;
  static const _maxMessages = 1000;
  static const _maxTitleLength = 160;
  static const maxBytes = 24 * 1024 * 1024;
  static const _maxAttachmentBytes = 16 * 1024 * 1024;
  static const tooLarge = ChatException(
    'Conversation files can be up to 24 MB.',
  );
  static const invalid = ChatException('This conversation file is invalid.');

  final String title;
  final ChatMode mode;
  final ChatOptions options;
  final List<Message> messages;
  final Map<String, ChatAttachment> attachments;

  static Future<Uint8List> encode({
    required String title,
    required ChatMode mode,
    required ChatOptions options,
    required List<Message> messages,
    required Future<ChatAttachment?> Function(String, String) loadAttachment,
  }) async {
    if (messages.length > _maxMessages) {
      throw const ChatException(
        'A conversation file can contain up to 1,000 messages.',
      );
    }
    if (!messages.any((message) => message.role == Role.user)) {
      throw const ChatException('This conversation has no prompts to export.');
    }
    final references = <(String, String), String>{};
    final files = <String, Map<String, String>>{};
    final records = <Map<String, dynamic>>[];
    var attachmentBytes = 0;
    var encodedBytes = 0;

    for (final (index, message) in messages.indexed) {
      for (final reference in message.attachmentRefs.toSet()) {
        final source = (message.chatId, reference);
        if (references.containsKey(source)) continue;
        final attachment = await loadAttachment(message.chatId, reference);
        if (attachment == null) {
          throw const ChatException(
            'An attachment in this conversation is unavailable.',
          );
        }
        attachmentBytes += attachment.bytes.length;
        if (attachmentBytes > _maxAttachmentBytes) throw tooLarge;
        final encoded = base64Encode(attachment.bytes);
        final key = 'file-${files.length + 1}';
        references[source] = key;
        files[key] = {
          'kind': attachment is ChatDocument ? 'document' : 'image',
          'name': _portableName(attachment.name),
          'data': encoded,
        };
        encodedBytes += encoded.length;
      }
      // Use archive-local IDs so legacy paths and device storage keys stay local.
      final record = message
          .copyWith(
            chatId: 'archive',
            messageId: 'message-${index + 1}',
            imagesUrls: [
              for (final key in message.imagesUrls)
                references[(message.chatId, key)]!,
            ],
            documentRefs: [
              for (final key in message.documentRefs)
                references[(message.chatId, key)]!,
            ],
          )
          .toMap();
      encodedBytes += utf8.encode(jsonEncode(record)).length;
      if (encodedBytes > maxBytes) throw tooLarge;
      records.add(record);
    }

    final heading = title.trim().isEmpty
        ? 'Conversation'
        : String.fromCharCodes(title.trim().runes.take(_maxTitleLength));
    final bytes = utf8.encode(
      jsonEncode({
        'format': _format,
        'version': _version,
        'title': heading,
        'mode': mode.name,
        'options': options.toMap(),
        'messages': records,
        'attachments': files,
      }),
    );
    if (bytes.length > maxBytes) throw tooLarge;
    return bytes;
  }

  factory ChatArchive.decode(Uint8List bytes) {
    if (bytes.length > maxBytes) throw tooLarge;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['format'] != _format) {
        throw const ChatException('Choose an AI Chatbot conversation file.');
      }
      if (decoded['version'] != _version) {
        throw const ChatException(
          'This conversation file uses an unsupported version.',
        );
      }
      if (decoded case {
        'title': final String title,
        'mode': final String mode,
        'options': final Map options,
        'messages': final List records,
        'attachments': final Map files,
      }) {
        if (title.trim().isEmpty ||
            title.runes.length > _maxTitleLength ||
            records.isEmpty ||
            records.length > _maxMessages) {
          throw invalid;
        }

        final attachments = _decodeAttachments(files);
        final messages = <Message>[];
        final ids = <String>{};
        final usedFiles = <String>{};
        for (final record in records) {
          final message = record is Map ? Message.tryFromMap(record) : null;
          if (message == null || !ids.add(message.messageId)) throw invalid;
          if (message.imagesUrls.any((key) => attachments[key] is! ChatImage) ||
              message.documentRefs.any(
                (key) => attachments[key] is! ChatDocument,
              )) {
            throw const ChatException(
              'This conversation file has missing or invalid attachments.',
            );
          }
          usedFiles.addAll(message.attachmentRefs);
          messages.add(message);
        }
        if (usedFiles.length != attachments.length ||
            !messages.any((message) => message.role == Role.user)) {
          throw invalid;
        }
        return ChatArchive._(
          title: title.trim(),
          mode: ChatMode.fromName(mode),
          options: ChatOptions.fromMap(options),
          messages: List.unmodifiable(messages),
          attachments: Map.unmodifiable(attachments),
        );
      }
      throw invalid;
    } on FormatException {
      throw invalid;
    }
  }

  static Map<String, ChatAttachment> _decodeAttachments(Map files) {
    final attachments = <String, ChatAttachment>{};
    var decodedBytes = 0;
    for (final entry in files.entries) {
      final key = entry.key;
      if (key is! String || key.isEmpty || entry.value is! Map) throw invalid;
      if (entry.value case {
        'kind': final String kind,
        'name': final String name,
        'data': final String data,
      }) {
        final bytes = base64Decode(data);
        decodedBytes += bytes.length;
        if (decodedBytes > _maxAttachmentBytes) throw tooLarge;
        final portableName = _portableName(name);
        attachments[key] = switch (kind) {
          'image' => ChatImage.fromBytes(portableName, bytes),
          'document' => ChatDocument.fromBytes(portableName, bytes),
          _ => throw invalid,
        };
      } else {
        throw invalid;
      }
    }
    return attachments;
  }

  static String _portableName(String name) {
    final label = name
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
        .trim();
    if (label.isEmpty || label.runes.length > 255) throw invalid;
    return label;
  }
}
