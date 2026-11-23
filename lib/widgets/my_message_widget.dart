import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/widgets/chat_attachments.dart';
import 'package:material_ui/material_ui.dart';

enum _PromptAction { useDraft, editInBranch }

class MyMessageWidget extends StatelessWidget {
  const MyMessageWidget({
    super.key,
    required this.message,
    required this.onUseDraft,
    this.onEditInBranch,
  });

  final Message message;
  final VoidCallback onUseDraft;
  final VoidCallback? onEditInBranch;

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
                if (message.attachmentRefs.isNotEmpty)
                  ChatAttachments.saved(message: message),
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
                    if (onEditInBranch case final edit?)
                      PopupMenuButton<_PromptAction>(
                        tooltip: 'Prompt actions',
                        icon: const Icon(Icons.more_vert_rounded, size: 19),
                        onSelected: (action) => switch (action) {
                          _PromptAction.useDraft => onUseDraft(),
                          _PromptAction.editInBranch => edit(),
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _PromptAction.editInBranch,
                            child: Text('Edit in a branch'),
                          ),
                          PopupMenuItem(
                            value: _PromptAction.useDraft,
                            child: Text('Use text as draft'),
                          ),
                        ],
                      )
                    else
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
