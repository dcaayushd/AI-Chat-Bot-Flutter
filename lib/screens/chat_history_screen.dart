import 'dart:async';

import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/models/reply_bookmark.dart';
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

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({
    super.key,
    required this.openChat,
    required this.openBookmark,
  });

  final Future<bool> Function(String?) openChat;
  final Future<bool> Function(ReplyBookmark) openBookmark;

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ChatHistoryPanel(
        onBack: () => Navigator.of(context).pop(),
        onOpenChat: (chatId) async {
          if (await openChat(chatId) && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        onOpenBookmark: (bookmark) async {
          if (await openBookmark(bookmark) && context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

enum _HistorySection { chats, bookmarks }

class ChatHistoryPanel extends StatefulWidget {
  const ChatHistoryPanel({
    super.key,
    required this.onOpenChat,
    required this.onOpenBookmark,
    this.onBack,
    this.onSettings,
  });

  final ValueChanged<String?> onOpenChat;
  final ValueChanged<ReplyBookmark> onOpenBookmark;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;

  @override
  State<ChatHistoryPanel> createState() => _ChatHistoryPanelState();
}

class _ChatHistoryPanelState extends State<ChatHistoryPanel> {
  final _searchController = TextEditingController();
  _HistorySection _section = _HistorySection.chats;
  late final _history = Boxes.getChatHistory().listenable();
  Timer? _searchDebounce;
  String _query = '';
  String? _lastQuery;
  List<ChatHistory>? _lastChats;
  Future<List<ChatHistory>>? _results;

  bool get _isSidebar => widget.onBack == null;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    _searchDebounce?.cancel();
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _query = '');
    } else {
      _searchDebounce = Timer(
        const Duration(milliseconds: 180),
        () => setState(() => _query = query),
      );
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _updateQuery('');
  }

  Future<void> _clearHistory(ChatProvider provider) async {
    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Clear history',
      content: 'Delete all saved chats, bookmarks, and drafts on this device?',
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

  Future<List<ChatHistory>> _search(
    ChatProvider provider,
    List<ChatHistory> chats,
  ) {
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
    final activeChatId = context.select<ChatProvider, String>(
      (chat) => chat.currentChatId,
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showingBookmarks = _section == _HistorySection.bookmarks;

    return ValueListenableBuilder<Box<ChatHistory>>(
      valueListenable: _history,
      builder: (context, box, _) {
        final chats = box.values.toList()
          ..sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.timestamp.compareTo(a.timestamp);
          });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSidebar) ...[
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.onPrimary,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Constants.appTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.tonalIcon(
                onPressed: () => widget.onOpenChat(null),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('New chat'),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: widget.onBack!,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('History', style: theme.textTheme.titleLarge),
                  ),
                  if (chats.isNotEmpty)
                    TextButton(
                      onPressed: () => _clearHistory(provider),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<_HistorySection>(
              segments: const [
                ButtonSegment(
                  value: _HistorySection.chats,
                  label: Text('Chats'),
                ),
                ButtonSegment(
                  value: _HistorySection.bookmarks,
                  label: Text('Saved replies'),
                ),
              ],
              selected: {_section},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.single),
            ),
            const SizedBox(height: 12),
            if (_isSidebar ||
                chats.isNotEmpty ||
                _query.isNotEmpty ||
                showingBookmarks) ...[
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) => TextField(
                  controller: _searchController,
                  onChanged: _updateQuery,
                  decoration: InputDecoration(
                    hintText: showingBookmarks
                        ? 'Search saved replies'
                        : _isSidebar
                        ? 'Search chats'
                        : 'Search titles and messages',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isSidebar && chats.isNotEmpty && !showingBookmarks)
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved chats',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear history',
                    onPressed: () => _clearHistory(provider),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  ),
                ],
              ),
            Expanded(
              child: showingBookmarks
                  ? _buildBookmarks(provider.findBookmarks(chats, _query))
                  : _query.isEmpty || chats.isEmpty
                  ? _buildResults(provider, chats, activeChatId)
                  : FutureBuilder<List<ChatHistory>>(
                      future: _search(provider, chats),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: 'Searching chats',
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Could not search chat history.'),
                          );
                        }
                        return _buildResults(
                          provider,
                          snapshot.data ?? [],
                          activeChatId,
                          filtered: true,
                        );
                      },
                    ),
            ),
            if (widget.onSettings case final onSettings?) ...[
              const Divider(),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  label: const Text('Settings'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBookmarks(List<ReplyBookmark> bookmarks) {
    final theme = Theme.of(context);
    if (bookmarks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                size: 26,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(_query.isEmpty ? 'No saved replies' : 'No matching replies'),
              if (_query.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Bookmark a reply to find it here.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TextButton(
                  onPressed: _clearSearch,
                  child: const Text('Clear search'),
                ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 10),
      itemCount: bookmarks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final preview = String.fromCharCodes(
          bookmark.text.trim().runes.take(180),
        );
        return Card(
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            leading: Icon(
              Icons.bookmark_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            horizontalTitleGap: 8,
            title: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              bookmark.chatTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => widget.onOpenBookmark(bookmark),
          ),
        );
      },
    );
  }

  Widget _buildResults(
    ChatProvider provider,
    List<ChatHistory> chats,
    String activeChatId, {
    bool filtered = false,
  }) {
    if (chats.isEmpty) {
      return EmptyHistoryWidget(
        isFiltered: filtered,
        onAction: filtered
            ? _clearSearch
            : (_isSidebar ? null : () => widget.onOpenChat(null)),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: _isSidebar ? 8 : MediaQuery.paddingOf(context).bottom + 12,
      ),
      itemCount: chats.length,
      separatorBuilder: (_, _) => SizedBox(height: _isSidebar ? 4 : 10),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final row = ChatHistoryWidget(
          key: ValueKey(chat.chatId),
          chat: chat,
          compact: _isSidebar,
          selected: chat.chatId == activeChatId,
          onOpen: () => widget.onOpenChat(chat.chatId),
          onDelete: () => _deleteChat(provider, chat),
        );
        if (_isSidebar) return row;

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
              padding: const EdgeInsetsDirectional.only(end: 18),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          ),
          child: row,
        );
      },
    );
  }
}
