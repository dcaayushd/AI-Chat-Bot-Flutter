import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';
import 'package:chatbotapp/widgets/app_screen_scaffold.dart';
import 'package:chatbotapp/widgets/chat_history_widget.dart';
import 'package:chatbotapp/widgets/empty_history_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _lastQuery;
  List<ChatHistory>? _lastChats;
  Future<List<ChatHistory>>? _results;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) =>
      setState(() => _query = value.trim().toLowerCase());

  Future<void> _clearHistory(ChatProvider provider) async {
    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Clear history',
      content: 'Delete all chats saved on this device?',
      actionText: 'Clear',
    );
    if (!mounted || !confirmed) return;
    try {
      await provider.clearAllChats();
    } catch (error) {
      if (mounted) showAppSnackBar(context, formatChatError(error));
    }
  }

  Future<void> _deleteChat(ChatProvider provider, ChatHistory chat) async {
    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Delete chat',
      content: 'Delete this conversation from your history?',
      actionText: 'Delete',
    );
    if (!mounted || !confirmed) return;
    try {
      await provider.deleteChat(chat.chatId);
    } catch (error) {
      if (mounted) showAppSnackBar(context, formatChatError(error));
    }
  }

  Future<void> _openChat(ChatProvider provider, [ChatHistory? chat]) async {
    if (provider.hasMessages &&
        (provider.historyOff || provider.storageError != null) &&
        provider.currentChatId != chat?.chatId) {
      final confirmed = await showAnimatedConfirmationDialog(
        context: context,
        title: 'Switch conversations?',
        content: 'The current conversation has unsaved messages.',
        actionText: 'Continue',
      );
      if (!mounted || !confirmed) return;
    }
    try {
      if (chat == null) {
        await provider.newChat();
      } else {
        await provider.openChat(chat.chatId);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showAppSnackBar(context, formatChatError(error));
    }
  }

  Future<List<ChatHistory>> _search(
      ChatProvider provider, List<ChatHistory> chats) {
    if (_lastQuery != _query || !listEquals(_lastChats, chats)) {
      _lastQuery = _query;
      _lastChats = chats;
      _results = provider.searchChats(chats, _query);
    }
    return _results!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    return AppScreenScaffold(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ValueListenableBuilder<Box<ChatHistory>>(
        valueListenable: Boxes.getChatHistory().listenable(),
        builder: (context, box, _) {
          final chats = box.values.toList()
            ..sort((a, b) {
              if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
              return b.timestamp.compareTo(a.timestamp);
            });
          return Column(
            children: [
              Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('History',
                          style: Theme.of(context).textTheme.titleLarge)),
                  if (chats.isNotEmpty)
                    TextButton(
                      onPressed: () => _clearHistory(provider),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (chats.isNotEmpty) ...[
                TextField(
                  controller: _searchController,
                  onChanged: _updateQuery,
                  decoration: InputDecoration(
                    hintText: 'Search titles and messages',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _query.isEmpty || chats.isEmpty
                    ? _buildResults(provider, chats, filtered: false)
                    : FutureBuilder<List<ChatHistory>>(
                        future: _search(provider, chats),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Could not search chat history.'));
                          }
                          return _buildResults(provider, snapshot.data ?? [],
                              filtered: true);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _updateQuery('');
  }

  Widget _buildResults(ChatProvider provider, List<ChatHistory> chats,
      {required bool filtered}) {
    if (chats.isEmpty) {
      return EmptyHistoryWidget(
        isFiltered: filtered,
        onAction: filtered ? _clearSearch : () => _openChat(provider),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 12),
      itemCount: chats.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final colors = Theme.of(context).colorScheme;
        return Dismissible(
          key: ValueKey(chat.chatId),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _deleteChat(provider, chat);
            return false; // Hive removes the row when the deletion succeeds.
          },
          background: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.delete_outline_rounded,
                    color: colors.onErrorContainer),
              ),
            ),
          ),
          child: ChatHistoryWidget(
            chat: chat,
            onOpen: () => _openChat(provider, chat),
            onDelete: () => _deleteChat(provider, chat),
          ),
        );
      },
    );
  }
}
