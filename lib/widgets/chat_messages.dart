import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/widgets/assistant_message_widget.dart';
import 'package:chatbotapp/widgets/my_message_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChatMessages extends StatelessWidget {
  const ChatMessages({
    super.key,
    required this.scrollController,
    required this.onRetry,
    required this.onUseDraft,
  });

  final ScrollController scrollController;
  final VoidCallback onRetry;
  final ValueChanged<String> onUseDraft;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final count = chat.visibleMessageCount;
    final problem = chat.generationError;
    final needsRetry =
        !chat.isBusy && (problem != null || chat.hasUnansweredPrompt);
    final showFooter = needsRetry || chat.storageError != null;

    return ListView.builder(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      itemCount: count + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == count) {
          return _ChatNotice(
            generationError: problem,
            storageError: chat.storageError,
            onRetry: needsRetry ? onRetry : null,
          );
        }
        final message = chat.visibleMessageAt(index);
        if (message.role == Role.user) {
          return MyMessageWidget(
            key: ValueKey(message.messageId),
            message: message,
            onUseDraft: () => onUseDraft(message.text),
          );
        }
        return AssistantMessageWidget(
          key: ValueKey(message.messageId),
          message: message,
          streaming: message.messageId == chat.streamingReply?.messageId,
          onRegenerate: index == count - 1 && !chat.isBusy && !needsRetry
              ? onRetry
              : null,
        );
      },
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({this.generationError, this.storageError, this.onRetry});

  final String? generationError;
  final String? storageError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onRetry != null)
                Row(
                  children: [
                    Expanded(child: Text(generationError ?? 'No reply yet')),
                    TextButton(
                        onPressed: onRetry, child: const Text('Try again')),
                  ],
                ),
              if (storageError case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
