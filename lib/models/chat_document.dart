import 'dart:convert';
import 'dart:typed_data';

import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

class ChatDocument extends ChatAttachment {
  const ChatDocument._(super.name, super.mimeType, super.bytes, this.text);

  static const maxCount = 2;
  static const maxFileBytes = 6 * 1024 * 1024;
  static const maxTextLength = 20000;
  static const _maxTextBytes = maxTextLength * 4 + 3;
  static const _pdfSignature = [0x25, 0x50, 0x44, 0x46, 0x2d];
  static const _plainTextExtensions = {'.txt', '.md', '.csv', '.json'};
  static const acceptedTypes = XTypeGroup(
    label: 'Documents',
    extensions: ['pdf', 'txt', 'md', 'csv', 'json'],
    mimeTypes: [
      'application/pdf',
      'text/plain',
      'text/markdown',
      'text/csv',
      'application/json',
    ],
    uniformTypeIdentifiers: [
      'com.adobe.pdf',
      'public.plain-text',
      'net.daringfireball.markdown',
      'public.comma-separated-values-text',
      'public.json',
    ],
  );

  final String? text;

  static Future<ChatDocument> fromFile(XFile file) async {
    if (await file.length() > maxFileBytes) {
      throw const ChatException('Each document must be 6 MB or smaller.');
    }
    return ChatDocument.fromBytes(file.name, await file.readAsBytes());
  }

  factory ChatDocument.fromBytes(String name, Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const ChatException('Each document must be 6 MB or smaller.');
    }
    final fileName = p
        .basename(name)
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
    final extension = p.extension(fileName).toLowerCase();
    if (extension == '.pdf') {
      if (bytes.length <= _pdfSignature.length ||
          !_pdfSignature.indexed.every((part) => bytes[part.$1] == part.$2)) {
        throw const ChatException(
          'This file does not have a valid PDF header.',
        );
      }
      return ChatDocument._(
        fileName,
        'application/pdf',
        bytes.asUnmodifiableView(),
        null,
      );
    }
    if (!_plainTextExtensions.contains(extension)) {
      throw const ChatException(
        'Choose a PDF, TXT, Markdown, CSV, or JSON file.',
      );
    }
    if (bytes.length > _maxTextBytes) {
      throw const ChatException('Keep each text file under 20,000 characters.');
    }
    final String decoded;
    try {
      decoded = utf8.decode(bytes);
    } on FormatException {
      throw const ChatException('Choose a text file encoded as UTF-8.');
    }
    if (decoded.trim().isEmpty || decoded.contains('\u0000')) {
      throw const ChatException('Choose a text file with readable content.');
    }
    if (decoded.length > maxTextLength) {
      throw const ChatException('Keep each text file under 20,000 characters.');
    }
    return ChatDocument._(
      fileName,
      'text/plain',
      bytes.asUnmodifiableView(),
      decoded,
    );
  }

  @override
  Map<String, dynamic> toMap() => {...super.toMap(), 'kind': 'document'};
}
