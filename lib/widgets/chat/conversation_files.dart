import 'package:chatbotapp/models/chat_archive.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart' as sharing;

const _conversationType = files.XTypeGroup(
  label: 'Chat conversation files',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

Future<ChatArchive?> pickConversationFile() async {
  final file = await files.openFile(acceptedTypeGroups: [_conversationType]);
  if (file == null) return null;
  if (await file.length() > ChatArchive.maxBytes) throw ChatArchive.tooLarge;
  return ChatArchive.decode(await file.readAsBytes());
}

Future<void> exportConversationFile(
  BuildContext context, {
  required String title,
  required Uint8List bytes,
}) async {
  final slug = title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
  final cleaned = String.fromCharCodes(slug.runes.take(64))
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final filename = '${cleaned.isEmpty ? 'conversation' : cleaned}.chatbot.json';
  final file = files.XFile.fromData(
    bytes,
    mimeType: 'application/json',
    name: filename,
  );

  final desktop = switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };
  if (!kIsWeb && desktop) {
    final location = await files.getSaveLocation(
      acceptedTypeGroups: [_conversationType],
      suggestedName: filename,
    );
    if (location == null) return;
    await file.saveTo(location.path);
    if (context.mounted) showAppSnackBar(context, 'Conversation file saved');
    return;
  }

  final renderObject = context.findRenderObject();
  final viewport = MediaQuery.sizeOf(context);
  final origin = renderObject is RenderBox && renderObject.hasSize
      ? renderObject.localToGlobal(Offset.zero) & renderObject.size
      : Rect.fromLTWH(viewport.width / 2, viewport.height / 2, 1, 1);
  await sharing.SharePlus.instance.share(
    sharing.ShareParams(
      files: [file],
      fileNameOverrides: [filename],
      title: 'Export conversation',
      sharePositionOrigin: origin,
    ),
  );
}
