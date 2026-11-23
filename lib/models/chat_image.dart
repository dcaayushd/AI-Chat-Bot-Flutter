import 'dart:typed_data';

import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class ChatImage extends ChatAttachment {
  const ChatImage._(super.name, super.mimeType, super.bytes);

  static const maxFileBytes = 4 * 1024 * 1024;
  static const _supportedTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static Future<ChatImage> fromFile(XFile file) async {
    if (await file.length() > maxFileBytes) {
      throw const ChatException('Each image must be 4 MB or smaller.');
    }
    return ChatImage.fromBytes(file.name, await file.readAsBytes());
  }

  factory ChatImage.fromBytes(String name, Uint8List bytes) {
    final mimeType = lookupMimeType('', headerBytes: bytes);
    if (bytes.isEmpty ||
        mimeType == null ||
        !_supportedTypes.contains(mimeType)) {
      throw const ChatException(
        'Choose a JPEG, PNG, WebP, HEIC, or HEIF image.',
      );
    }
    if (bytes.length > maxFileBytes) {
      throw const ChatException('Each image must be 4 MB or smaller.');
    }
    return ChatImage._(name, mimeType, bytes.asUnmodifiableView());
  }
}
