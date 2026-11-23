import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChatAttachments extends StatelessWidget {
  const ChatAttachments.draft({
    super.key,
    required List<ChatAttachment> attachments,
    this.onRemoveAt,
    this.height = 96,
  }) : _attachments = attachments,
       _message = null;

  const ChatAttachments.saved({super.key, required Message message})
    : _message = message,
      _attachments = const [],
      height = 96,
      onRemoveAt = null;

  final List<ChatAttachment> _attachments;
  final Message? _message;
  final ValueChanged<int>? onRemoveAt;
  final double height;

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final references = message?.attachmentRefs.toList();
    final count = references?.length ?? _attachments.length;
    if (count == 0) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (message != null) {
            final reference = references![index];
            return _SavedThumbnail(
              key: ValueKey(reference),
              chatId: message.chatId,
              reference: reference,
            );
          }
          return _Thumbnail(
            attachment: _attachments[index],
            onRemove: onRemoveAt == null ? null : () => onRemoveAt!(index),
          );
        },
      ),
    );
  }
}

class _SavedThumbnail extends StatefulWidget {
  const _SavedThumbnail({
    super.key,
    required this.chatId,
    required this.reference,
  });

  final String chatId;
  final String reference;

  @override
  State<_SavedThumbnail> createState() => _SavedThumbnailState();
}

class _SavedThumbnailState extends State<_SavedThumbnail> {
  late final Future<ChatAttachment?> _attachment = context
      .read<ChatProvider>()
      .attachmentFor(widget.chatId, widget.reference);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatAttachment?>(
      future: _attachment,
      builder: (context, snapshot) => _Thumbnail(
        attachment: snapshot.data,
        loading: snapshot.connectionState != ConnectionState.done,
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.attachment,
    this.onRemove,
    this.loading = false,
  });

  final ChatAttachment? attachment;
  final VoidCallback? onRemove;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final file = attachment;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: file is ChatDocument ? 186 : 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: loading
                ? const Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : switch (file) {
                    ChatImage() => InkWell(
                      onTap: () => _openImage(context, file),
                      child: Image.memory(
                        file.bytes,
                        semanticLabel: file.name,
                        cacheWidth: 256,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.image_outlined),
                      ),
                    ),
                    ChatDocument() => InkWell(
                      onTap: () => _openDocument(context, file),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          12,
                          4,
                          onRemove == null ? 12 : 44,
                          4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              file.text == null
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.description_outlined,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _ => const Tooltip(
                      message: 'Attachment unavailable',
                      child: Icon(Icons.insert_drive_file_outlined),
                    ),
                  },
          ),
          if (onRemove != null)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: IconButton.filled(
                onPressed: onRemove,
                tooltip: file is ChatImage ? 'Remove image' : 'Remove document',
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }

  void _openDocument(BuildContext context, ChatDocument document) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(document.name),
        content: switch (document.text) {
          final String text => SelectableText(text),
          null => Text('PDF · ${(document.bytes.length / 1024).ceil()} KB'),
        },
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, ChatImage image) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 650),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    image.bytes,
                    semanticLabel: image.name,
                    errorBuilder: (context, error, stack) =>
                        const Text('This image cannot be previewed.'),
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close image',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
