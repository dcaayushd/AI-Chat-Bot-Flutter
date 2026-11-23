import 'dart:typed_data';

abstract class ChatAttachment {
  const ChatAttachment(this.name, this.mimeType, this.bytes);

  static const maxCount = 4;
  static const maxRequestBytes = 10 * 1024 * 1024;

  final String name;
  final String mimeType;
  final Uint8List bytes;

  Map<String, dynamic> toMap() => {
    'name': name,
    'mimeType': mimeType,
    'bytes': bytes,
  };
}
