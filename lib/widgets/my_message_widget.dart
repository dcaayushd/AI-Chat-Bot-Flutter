import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/widgets/preview_images_widget.dart';
import 'package:material_ui/material_ui.dart';

class MyMessageWidget extends StatelessWidget {
  const MyMessageWidget({
    super.key,
    required this.message,
    required this.onUseDraft,
  });

  final Message message;
  final VoidCallback onUseDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.85),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imagesUrls.isNotEmpty)
                  PreviewImagesWidget.saved(message: message),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SelectableText(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Use text as draft',
                      color: colors.onPrimaryContainer,
                      onPressed: onUseDraft,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
