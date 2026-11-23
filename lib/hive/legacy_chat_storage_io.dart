import 'dart:io';
import 'dart:typed_data';

import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:path/path.dart' as p;

final _chatIdPattern = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

Future<Directory?> _mediaDirectory(String? storageDirectory) async {
  if (storageDirectory == null) return null;
  final directory = Directory(p.join(storageDirectory, 'chat_media'));
  final type = await FileSystemEntity.type(directory.path, followLinks: false);
  return type == FileSystemEntityType.directory ? directory : null;
}

Future<Directory?> _chatDirectory(
  String? storageDirectory,
  String chatId,
) async {
  if (!_chatIdPattern.hasMatch(chatId)) return null;
  final root = await _mediaDirectory(storageDirectory);
  if (root == null) return null;
  final directory = Directory(p.join(root.path, chatId));
  final type = await FileSystemEntity.type(directory.path, followLinks: false);
  return type == FileSystemEntityType.directory ? directory : null;
}

Future<Uint8List?> readLegacyChatImage(
  String? storageDirectory,
  String chatId,
  String reference,
) async {
  try {
    if (p.basename(p.dirname(reference)) != chatId ||
        p.basename(p.dirname(p.dirname(reference))) != 'chat_media') {
      return null;
    }
    final directory = await _chatDirectory(storageDirectory, chatId);
    if (directory == null) return null;
    final file = File(p.join(directory.path, p.basename(reference)));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > ChatImage.maxFileBytes) {
      return null;
    }
    return await file.readAsBytes();
  } on FileSystemException {
    return null;
  }
}

Future<void> deleteLegacyChatImages(
  String? storageDirectory,
  String chatId,
) async {
  final directory = await _chatDirectory(storageDirectory, chatId);
  if (directory != null) await directory.delete(recursive: true);
}

Future<void> clearLegacyChatImages(String? storageDirectory) async {
  final directory = await _mediaDirectory(storageDirectory);
  if (directory != null) await directory.delete(recursive: true);
}

Future<List<String>> legacyMessageBoxes(String? storageDirectory) async {
  if (storageDirectory == null) return [];
  final names = <String>[];
  final directory = Directory(storageDirectory);
  const prefix = Constants.chatMessagesBox;
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is! File || p.extension(entry.path) != '.hive') continue;
    final name = p.basenameWithoutExtension(entry.path);
    if (name.startsWith(prefix) &&
        _chatIdPattern.hasMatch(name.substring(prefix.length))) {
      names.add(name);
    }
  }
  return names;
}
