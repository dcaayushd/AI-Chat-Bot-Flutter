import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class PreviewImagesWidget extends StatelessWidget {
  const PreviewImagesWidget.draft({
    super.key,
    required List<ChatImage> images,
    this.onRemoveAt,
    this.height = 96,
  })  : _images = images,
        _message = null;

  const PreviewImagesWidget.saved({super.key, required Message message})
      : _message = message,
        _images = const [],
        height = 96,
        onRemoveAt = null;

  final List<ChatImage> _images;
  final Message? _message;
  final ValueChanged<int>? onRemoveAt;
  final double height;

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final count = message?.imagesUrls.length ?? _images.length;
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
            final reference = message.imagesUrls[index];
            return _SavedThumbnail(
              key: ValueKey(reference),
              chatId: message.chatId,
              reference: reference,
            );
          }
          return _Thumbnail(
            image: _images[index],
            onRemove: onRemoveAt == null ? null : () => onRemoveAt!(index),
          );
        },
      ),
    );
  }
}

class _SavedThumbnail extends StatefulWidget {
  const _SavedThumbnail(
      {super.key, required this.chatId, required this.reference});

  final String chatId;
  final String reference;

  @override
  State<_SavedThumbnail> createState() => _SavedThumbnailState();
}

class _SavedThumbnailState extends State<_SavedThumbnail> {
  late final Future<ChatImage?> _image =
      context.read<ChatProvider>().imageFor(widget.chatId, widget.reference);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatImage?>(
      future: _image,
      builder: (context, snapshot) => _Thumbnail(
        image: snapshot.data,
        loading: snapshot.connectionState != ConnectionState.done,
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.image, this.onRemove, this.loading = false});

  final ChatImage? image;
  final VoidCallback? onRemove;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 84,
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
                : image == null
                    ? const Tooltip(
                        message: 'Image unavailable',
                        child: Icon(Icons.broken_image_outlined),
                      )
                    : InkWell(
                        onTap: () => _openImage(context, image),
                        child: Image.memory(
                          image.bytes,
                          semanticLabel: image.name,
                          cacheWidth: 256,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.image_outlined),
                        ),
                      ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filled(
                onPressed: onRemove,
                tooltip: 'Remove image',
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 40, height: 40),
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
