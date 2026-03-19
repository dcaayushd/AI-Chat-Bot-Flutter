import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';
import 'package:chatbotapp/widgets/app_screen_scaffold.dart';
import 'package:chatbotapp/widgets/chat_history_widget.dart';
import 'package:chatbotapp/widgets/empty_history_widget.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    _searchController.addListener(_onSearchChanged);
    super.initState();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _removeChat(
    ChatProvider chatProvider,
    ChatHistory chat,
  ) async {
    await chatProvider.deleteChatMessages(chatId: chat.chatId);
    await chat.delete();
  }

  Future<void> _clearAllHistory(BuildContext context) async {
    final chatProvider = context.read<ChatProvider>();

    if (!context.mounted) {
      return;
    }

    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Clear history',
      content: 'Remove all chats?',
      actionText: 'Clear',
    );

    if (!confirmed) {
      return;
    }

    await chatProvider.clearAllChats();
  }

  Future<bool> _deleteChat(
    BuildContext context,
    ChatHistory chat,
  ) async {
    final chatProvider = context.read<ChatProvider>();

    if (!context.mounted) {
      return false;
    }

    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Delete chat',
      content: 'Remove this chat?',
      actionText: 'Delete',
    );

    if (confirmed) {
      await _removeChat(chatProvider, chat);
    }

    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        0,
      ),
      child: ValueListenableBuilder<Box<ChatHistory>>(
        valueListenable: Boxes.getChatHistory().listenable(),
        builder: (context, box, _) {
          final allChats = box.values.toList().cast<ChatHistory>()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final filteredChats = _query.isEmpty
              ? allChats
              : allChats
                  .where(
                    (chat) =>
                        chat.prompt.toLowerCase().contains(_query) ||
                        chat.response.toLowerCase().contains(_query),
                  )
                  .toList();

          return Column(
            children: [
              Row(
                children: [
                  AppIconButton(
                    icon: CupertinoIcons.back,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          allChats.isEmpty
                              ? 'No chats yet'
                              : '${allChats.length} chats',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (allChats.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _clearAllHistory(context),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (allChats.isNotEmpty) ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search chats',
                    isDense: true,
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(
                              CupertinoIcons.clear_circled_solid,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: filteredChats.isEmpty
                    ? EmptyHistoryWidget(isFiltered: _query.isNotEmpty)
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          bottom: homeIndicatorSpacing(
                            context,
                            base: 10,
                            factor: 0.1,
                            maxExtra: 4,
                          ),
                        ),
                        itemCount: filteredChats.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          return Dismissible(
                            key: ValueKey(chat.chatId),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _deleteChat(
                              context,
                              chat,
                            ),
                            background: _DeleteSwipeBackground(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ChatHistoryWidget(chat: chat),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground({
    required this.borderRadius,
  });

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.9),
        borderRadius: borderRadius,
      ),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          CupertinoIcons.delete_solid,
          size: 18,
          color: colorScheme.onError,
        ),
      ),
    );
  }
}
