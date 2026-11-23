import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

enum _HistoryAction { rename, pin, copy, delete }

class ChatHistoryWidget extends StatelessWidget {
  const ChatHistoryWidget({
    super.key,
    required this.chat,
    required this.onOpen,
    required this.onDelete,
    this.compact = false,
    this.selected = false,
  });

  final ChatHistory chat;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = chat.isPinned
        ? Icons.push_pin_rounded
        : chat.imagesUrls.isEmpty
        ? Icons.chat_bubble_outline_rounded
        : Icons.photo_library_outlined;

    if (compact) {
      return Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          selected: selected,
          selectedColor: colors.onPrimaryContainer,
          onTap: onOpen,
          leading: Icon(icon, size: 18),
          minLeadingWidth: 18,
          horizontalTitleGap: 10,
          contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 2),
          title: Text(
            chat.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: selected
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
          trailing: _actions(context),
        ),
      );
    }
    final date = MaterialLocalizations.of(context)
        .formatShortDate(chat.timestamp.toLocal());

    return Card(
      color: selected ? colors.primaryContainer : null,
      semanticContainer: false,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.response,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(date, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return PopupMenuButton<_HistoryAction>(
      tooltip: 'Conversation actions',
      iconSize: 20,
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _HistoryAction.rename,
          child: Text('Rename'),
        ),
        PopupMenuItem(
          value: _HistoryAction.pin,
          child: Text(chat.isPinned ? 'Unpin' : 'Pin'),
        ),
        const PopupMenuItem(
          value: _HistoryAction.copy,
          child: Text('Copy as Markdown'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _HistoryAction.delete,
          child: Text(
            'Delete chat',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    _HistoryAction action,
  ) async {
    final provider = context.read<ChatProvider>();
    try {
      switch (action) {
        case _HistoryAction.rename:
          final title = await showDialog<String>(
            context: context,
            builder: (context) => _RenameChatDialog(title: chat.displayTitle),
          );
          if (title != null) await provider.renameChat(chat.chatId, title);
        case _HistoryAction.pin:
          await provider.togglePin(chat.chatId);
        case _HistoryAction.copy:
          final transcript = await provider.exportSavedChat(chat);
          await Clipboard.setData(ClipboardData(text: transcript));
          if (context.mounted) {
            showAppSnackBar(context, 'Conversation copied as Markdown');
          }
        case _HistoryAction.delete:
          onDelete();
      }
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, formatChatError(error));
    }
  }
}

class _RenameChatDialog extends StatefulWidget {
  const _RenameChatDialog({required this.title});

  final String title;

  @override
  State<_RenameChatDialog> createState() => _RenameChatDialogState();
}

class _RenameChatDialogState extends State<_RenameChatDialog> {
  static const _maxLength = 80;
  late final _controller = TextEditingController(
    text: String.fromCharCodes(widget.title.runes.take(_maxLength)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename conversation'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: _maxLength,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _save,
            child: const Text('Save name'),
          ),
        ),
      ],
    );
  }
}
