import 'package:chatbotapp/models/chat_options.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/screens/chat_history_screen.dart';
import 'package:chatbotapp/screens/settings_screen.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/app_screen_scaffold.dart';
import 'package:chatbotapp/widgets/bottom_chat_field.dart';
import 'package:chatbotapp/widgets/chat/chat_dialogs.dart';
import 'package:chatbotapp/widgets/chat/chat_empty_state.dart';
import 'package:chatbotapp/widgets/chat/chat_header.dart';
import 'package:chatbotapp/widgets/chat_messages.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _sidebarBreakpoint = 1000.0;
  static const _sidebarWidth = 288.0;
  static const _conversationWidth = 780.0;

  final _scroll = ScrollController();
  final _composer = GlobalKey<BottomChatFieldState>();
  bool _followLatest = true;
  bool _jumpVisible = false;
  bool _scrollQueued = false;
  bool _autoScroll = true;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    _followLatest = _scroll.position.extentAfter < 72;
    _syncJumpButton();
  }

  void _syncJumpButton() {
    if (!mounted ||
        !_scroll.hasClients ||
        !_scroll.position.hasContentDimensions) {
      return;
    }
    final show = _scroll.position.extentAfter >= 72;
    if (show != _jumpVisible) setState(() => _jumpVisible = show);
  }

  void _queueScrollUpdate() {
    if (_scrollQueued) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (!mounted ||
          !_scroll.hasClients ||
          !_scroll.position.hasContentDimensions) {
        return;
      }
      final position = _scroll.position;
      if (_autoScroll && _followLatest && position.extentAfter > 0) {
        _scroll.jumpTo(position.maxScrollExtent);
      }
      _syncJumpButton();
    });
    // Metrics notifications can arrive after the current frame has ended.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _jumpToLatest() {
    _followLatest = true;
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    _queueScrollUpdate();
  }

  void _useDraft(String text) => _composer.currentState?.useDraft(text);

  Future<bool> _openChat(String? chatId) {
    final chat = context.read<ChatProvider>();
    if (chatId == chat.currentChatId) return Future.value(true);
    return _switchChat(
      chatId == null ? chat.newChat : () => chat.openChat(chatId),
      title: chatId == null ? 'Start a new chat?' : 'Switch conversations?',
      actionLabel: chatId == null ? 'Start new chat' : 'Switch chat',
    );
  }

  Future<void> _branch(String messageId) async {
    final chat = context.read<ChatProvider>();
    await _switchChat(
      () => chat.branchFrom(messageId),
      title: 'Branch from this reply?',
      actionLabel: 'Create branch',
    );
  }

  Future<bool> _switchChat(
    Future<void> Function() action, {
    required String title,
    required String actionLabel,
  }) async {
    final chat = context.read<ChatProvider>();
    final version = chat.conversationVersion;
    final hasDraft = _composer.currentState?.hasDraft ?? false;
    final unsaved =
        chat.hasMessages && (chat.historyOff || chat.storageError != null);
    final message = switch ((hasDraft, unsaved)) {
      (true, true) =>
        'The current draft and unsaved messages will be discarded.',
      (true, false) => 'The current draft will be discarded.',
      (false, true) => 'The current conversation has unsaved messages.',
      (false, false) => null,
    };
    if (message != null) {
      final confirmed = await showAnimatedConfirmationDialog(
        context: context,
        title: title,
        content: message,
        actionText: actionLabel,
      );
      if (!mounted || !confirmed || version != chat.conversationVersion) {
        return false;
      }
    }

    _composer.currentState?.cancelDictation();
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) showAppSnackBar(context, formatChatError(error));
      return false;
    }
  }

  Future<void> _changeOptions() async {
    final chat = context.read<ChatProvider>();
    final version = chat.conversationVersion;
    _composer.currentState?.cancelDictation();
    final options = await showDialog<ChatOptions>(
      context: context,
      builder: (context) => ChatOptionsDialog(options: chat.options),
    );
    if (!mounted || options == null || version != chat.conversationVersion)
      return;
    try {
      await chat.updateOptions(options);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, formatChatError(error), bottomOffset: 78);
      }
    }
  }

  Future<void> _editInBranch(Message message) async {
    final chat = context.read<ChatProvider>();
    final version = chat.conversationVersion;
    _composer.currentState?.cancelDictation();
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => PromptEditorDialog(
        text: message.text,
        maxLength: ChatProvider.maxPromptLength,
      ),
    );
    if (!mounted || prompt == null || version != chat.conversationVersion)
      return;
    await _switchChat(
      () => chat.editPromptInBranch(message.messageId, prompt),
      title: 'Send in a branch?',
      actionLabel: 'Send in branch',
    );
  }

  Future<void> _copyChat(ChatProvider chat) async {
    try {
      await Clipboard.setData(ClipboardData(text: chat.exportCurrentChat()));
      if (mounted) {
        showAppSnackBar(
          context,
          'Conversation copied as Markdown',
          bottomOffset: 78,
        );
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not copy the conversation.');
    }
  }

  void _openSettings() => _openPage(const SettingsScreen());

  void _openPage(Widget page) {
    _composer.currentState?.cancelDictation();
    final reduceMotion =
        context.read<SettingsProvider>().reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    final route = reduceMotion
        ? PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          )
        : CupertinoPageRoute<void>(builder: (context) => page);
    Navigator.of(context).push(route);
  }

  Widget _messageList(int version) {
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notice) {
              if (notice.depth == 0) _queueScrollUpdate();
              return false;
            },
            child: ChatMessages(
              key: ValueKey(version),
              scrollController: _scroll,
              onUseDraft: _useDraft,
              onBranch: _branch,
              onEditPrompt: _editInBranch,
            ),
          ),
        ),
        if (_jumpVisible)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: IconButton.filledTonal(
                tooltip: 'Jump to latest',
                onPressed: _jumpToLatest,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final userName = context.select(
      (UserProfileProvider user) => user.firstName,
    );
    final chat = context.read<ChatProvider>();
    final state = context.select(
      (ChatProvider chat) => (
        title: chat.title ?? 'Chat',
        hasMessages: chat.hasMessages,
        isConfigured: chat.isConfigured,
        historyOff: chat.historyOff,
        isBusy: chat.isBusy,
        isChangingConversation: chat.isChangingConversation,
        isGenerating: chat.isGenerating,
        canStop: chat.canStop,
        mode: chat.mode,
        version: chat.conversationVersion,
      ),
    );
    _autoScroll = settings.autoScroll;
    if (_version != state.version) {
      _version = state.version;
      _followLatest = true;
      _jumpVisible = false;
      _queueScrollUpdate();
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final colors = Theme.of(context).colorScheme;
    return AppScreenScaffold(
      maxContentWidth: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= _sidebarBreakpoint;
          final gutter = showSidebar ? 28.0 : 16.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showSidebar) ...[
                SizedBox(
                  width: _sidebarWidth,
                  child: ColoredBox(
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        20,
                        16,
                        bottomPadding + 10,
                      ),
                      child: ChatHistoryPanel(
                        onOpenChat: _openChat,
                        onSettings: _openSettings,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                key: const ValueKey('conversation'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    showSidebar ? 16 : 8,
                    gutter,
                    bottomPadding + 12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _conversationWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ChatHeader(
                            title: state.title,
                            userName: userName,
                            mode: state.mode,
                            historyOff: state.historyOff,
                            isBusy: state.isBusy,
                            onModeChanged: chat.setMode,
                            onOptions: _changeOptions,
                            onOpenHistory: showSidebar
                                ? null
                                : () => _openPage(
                                    ChatHistoryScreen(openChat: _openChat),
                                  ),
                            onOpenSettings: showSidebar ? null : _openSettings,
                            onNewChat: showSidebar
                                ? null
                                : () => _openChat(null),
                            onCopyChat: state.hasMessages
                                ? () => _copyChat(chat)
                                : null,
                          ),
                          const Divider(height: 20),
                          Expanded(
                            child: state.hasMessages
                                ? _messageList(state.version)
                                : ChatEmptyState(
                                    mode: state.mode,
                                    apiConfigured: state.isConfigured,
                                    showStarterPrompts:
                                        settings.showStarterPrompts,
                                    onSuggestionTap: _useDraft,
                                    onConnect: _openSettings,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          BottomChatField(
                            key: _composer,
                            conversationVersion: state.version,
                            isBusy: state.isBusy,
                            isChangingConversation:
                                state.isChangingConversation,
                            isGenerating: state.isGenerating,
                            canStop: state.canStop,
                            compact: constraints.maxHeight < 380,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
