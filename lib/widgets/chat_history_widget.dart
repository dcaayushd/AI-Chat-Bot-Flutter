import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:provider/provider.dart';

enum _HistoryAction {
  copyPrompt,
  deleteChat,
}

class ChatHistoryWidget extends StatelessWidget {
  const ChatHistoryWidget({
    super.key,
    required this.chat,
  });

  final ChatHistory chat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final chatProvider = context.read<ChatProvider>();
          await chatProvider.prepareChatRoom(
            isNewChat: false,
            chatID: chat.chatId,
          );
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: chat.imagesUrls.isEmpty
                      ? (isDark
                          ? colorScheme.primaryContainer.withValues(alpha: 0.78)
                          : colorScheme.primaryContainer)
                      : colorScheme.primaryContainer.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  chat.imagesUrls.isEmpty
                      ? CupertinoIcons.chat_bubble_2
                      : CupertinoIcons.photo_on_rectangle,
                  size: 17,
                  color: chat.imagesUrls.isEmpty
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.response,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (chat.imagesUrls.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${chat.imagesUrls.length} image${chat.imagesUrls.length == 1 ? '' : 's'}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showActions(context),
                child: Icon(
                  CupertinoIcons.ellipsis_circle,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showAdaptiveActionSheet<_HistoryAction>(
      context: context,
      title: chat.prompt,
      actions: const [
        AdaptiveSheetAction(
          label: 'Copy prompt',
          value: _HistoryAction.copyPrompt,
        ),
        AdaptiveSheetAction(
          label: 'Delete chat',
          value: _HistoryAction.deleteChat,
          isDestructive: true,
        ),
      ],
    );

    if (action == _HistoryAction.copyPrompt) {
      await Clipboard.setData(ClipboardData(text: chat.prompt));
      if (context.mounted) {
        showAppSnackBar(context, 'Prompt copied');
      }
      return;
    }

    if (action == _HistoryAction.deleteChat && context.mounted) {
      await _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final chatProvider = context.read<ChatProvider>();

    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Delete chat',
      content: 'Remove this chat?',
      actionText: 'Delete',
    );

    if (!confirmed) {
      return;
    }

    await chatProvider.deleteChatMessages(chatId: chat.chatId);
    await chat.delete();
  }
}
