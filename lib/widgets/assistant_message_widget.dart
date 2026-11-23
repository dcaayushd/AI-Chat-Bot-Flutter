import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/widgets/chat/assistant_response_content.dart';
import 'package:chatbotapp/widgets/chat/reply_versions_dialog.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class AssistantMessageWidget extends StatelessWidget {
  const AssistantMessageWidget({
    super.key,
    required this.message,
    required this.streaming,
    this.onRegenerate,
    this.onBranch,
    this.onContinue,
    this.onRestore,
  });

  final Message message;
  final bool streaming;
  final VoidCallback? onRegenerate;
  final VoidCallback? onBranch;
  final VoidCallback? onContinue;
  final ValueChanged<ReplyRevision>? onRestore;

  Future<void> _viewVersions(BuildContext context) async {
    final version = await showDialog<ReplyRevision>(
      context: context,
      builder: (context) =>
          ReplyVersionsDialog(message: message, canRestore: onRestore != null),
    );
    if (version != null && context.mounted) onRestore?.call(version);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = streaming
        ? (message.text.isEmpty ? 'Thinking…' : 'Writing…')
        : switch (message.status) {
            ReplyStatus.complete => null,
            ReplyStatus.stopped => 'Generation stopped',
            ReplyStatus.interrupted => 'Reply interrupted',
            ReplyStatus.truncated => 'Reply reached its length limit',
          };

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: const Icon(Icons.auto_awesome_outlined, size: 15),
                    ),
                    const SizedBox(width: 9),
                    Text('Gemini', style: theme.textTheme.labelLarge),
                    if (status != null) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            status,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (message.text.isNotEmpty)
                  AssistantResponseContent(text: message.text)
                else if (streaming)
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                if (!streaming && message.contextLimited)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Used recent conversation context',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (!streaming && message.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      children: [
                        if (onContinue != null)
                          TextButton.icon(
                            onPressed: onContinue,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Continue reply'),
                          ),
                        IconButton(
                          tooltip: 'Copy reply',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: message.text),
                            );
                            if (context.mounted) {
                              showAppSnackBar(
                                context,
                                'Reply copied',
                                bottomOffset: 78,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 18,
                          ),
                        ),
                        if (onRegenerate != null)
                          IconButton(
                            tooltip: 'Regenerate reply',
                            onPressed: onRegenerate,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                          ),
                        if (message.previousReplies.isNotEmpty)
                          IconButton(
                            tooltip: 'Reply versions',
                            onPressed: () => _viewVersions(context),
                            icon: const Icon(
                              Icons.history_toggle_off_rounded,
                              size: 19,
                            ),
                          ),
                        if (onBranch != null)
                          IconButton(
                            tooltip: 'Branch from this reply',
                            onPressed: onBranch,
                            icon: const Icon(
                              Icons.fork_right_rounded,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
