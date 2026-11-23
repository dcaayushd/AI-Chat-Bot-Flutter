import 'dart:typed_data';

Future<Uint8List?> readLegacyChatImage(
  String? storageDirectory,
  String chatId,
  String reference,
) async => null;

Future<void> deleteLegacyChatImages(
  String? storageDirectory,
  String chatId,
) async {}

Future<void> clearLegacyChatImages(String? storageDirectory) async {}

Future<List<String>> legacyMessageBoxes(String? storageDirectory) async => [];
