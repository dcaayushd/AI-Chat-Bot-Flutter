import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/assistant_message_widget.dart';
import 'package:chatbotapp/widgets/my_message_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChatMessages extends StatelessWidget {
  const ChatMessages({
    super.key,
    required this.scrollController,
    required this.onUseDraft,
    required this.onBranch,
    required this.onEditPrompt,
    this.anchorIndex = 0,
    this.highlightedMessageId,
  });

  static const _center = ValueKey('conversation-center');

  final ScrollController scrollController;
  final ValueChanged<String> onUseDraft;
  final ValueChanged<String> onBranch;
  final ValueChanged<Message> onEditPrompt;
  final int anchorIndex;
  final String? highlightedMessageId;

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, formatChatError(error), bottomOffset: 78);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final count = chat.visibleMessageCount;
    final problem = chat.generationError;
    final needsRetry =
        !chat.isBusy && (problem != null || chat.hasUnansweredPrompt);
    final showFooter = needsRetry || chat.storageError != null;

    Widget item(BuildContext context, int index) {
      if (index == count) {
        return _ChatNotice(
          generationError: problem,
          storageError: chat.storageError,
          onRetry: needsRetry
              ? () => _runAction(
                  context,
                  () => chat.retryLastReply(afterError: true),
                )
              : null,
        );
      }
      final message = chat.visibleMessageAt(index);
      if (message.role == Role.user) {
        return _highlight(
          context,
          message,
          MyMessageWidget(
            key: ValueKey(message.messageId),
            message: message,
            onUseDraft: () => onUseDraft(message.text),
            onEditInBranch: chat.canBranch ? () => onEditPrompt(message) : null,
          ),
        );
      }
      final isLatest = index == count - 1 && !chat.isBusy;
      return _highlight(
        context,
        message,
        AssistantMessageWidget(
          key: ValueKey(message.messageId),
          message: message,
          streaming: message.messageId == chat.streamingReply?.messageId,
          onRegenerate: isLatest && !needsRetry
              ? () => _runAction(context, chat.retryLastReply)
              : null,
          onContinue: isLatest && chat.canContinueLastReply
              ? () => _runAction(context, chat.continueLastReply)
              : null,
          onRestore: isLatest
              ? (revision) => _runAction(
                  context,
                  () => chat.restoreReply(message.messageId, revision),
                )
              : null,
          onBranch: chat.canBranch ? () => onBranch(message.messageId) : null,
          onBookmark: chat.canBranch
              ? () => _runAction(
                  context,
                  () => chat.toggleReplyBookmark(message.messageId),
                )
              : null,
        ),
      );
    }

    final start = anchorIndex.clamp(0, count);
    final total = count + (showFooter ? 1 : 0);
    Widget list(int itemCount, int Function(int) messageIndex) => SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final absoluteIndex = messageIndex(index);
          return IndexedSemantics(
            index: absoluteIndex,
            child: item(context, absoluteIndex),
          );
        },
        childCount: itemCount,
        addSemanticIndexes: false,
      ),
    );

    // Both sides of the anchor are lazy, including when jumping into a long chat.
    return CustomScrollView(
      center: _center,
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      semanticChildCount: total,
      slivers: [
        if (start > 0) list(start, (index) => start - 1 - index),
        SliverPadding(
          key: _center,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          sliver: list(total - start, (index) => start + index),
        ),
      ],
    );
  }

  Widget _highlight(BuildContext context, Message message, Widget child) {
    if (message.messageId != highlightedMessageId) return child;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: true,
      child: Container(
        key: const ValueKey('selected-message'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          color: colors.primaryContainer.withValues(alpha: 0.42),
          border: Border.all(color: colors.primary),
        ),
        child: child,
      ),
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
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
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
