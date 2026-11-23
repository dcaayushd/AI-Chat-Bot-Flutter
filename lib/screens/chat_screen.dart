import 'package:chatbotapp/models/chat_mode.dart';
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

  Future<void> _newChat(ChatProvider chat) async {
    if (chat.hasMessages && (chat.historyOff || chat.storageError != null)) {
      final confirmed = await showAnimatedConfirmationDialog(
        context: context,
        title: 'Start a new chat?',
        content: 'The current conversation has unsaved messages.',
        actionText: 'Start new chat',
      );
      if (!mounted || !confirmed) return;
    }
    try {
      await chat.newChat();
    } catch (error) {
      if (mounted) showAppSnackBar(context, formatChatError(error));
    }
  }

  Future<void> _retry() async {
    try {
      await context.read<ChatProvider>().retryLastReply();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, formatChatError(error), bottomOffset: 78);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final userName = context.select<UserProfileProvider, String>(
      (profile) => profile.firstName,
    );
    final chat = context.read<ChatProvider>();
    _autoScroll = settings.autoScroll;

    return Selector<
      ChatProvider,
      ({
        bool hasMessages,
        bool isConfigured,
        bool historyOff,
        bool isBusy,
        bool isGenerating,
        bool canStop,
        ChatMode mode,
        int version,
      })
    >(
      selector: (context, chat) => (
        hasMessages: chat.hasMessages,
        isConfigured: chat.isConfigured,
        historyOff: chat.historyOff,
        isBusy: chat.isBusy,
        isGenerating: chat.isGenerating,
        canStop: chat.canStop,
        mode: chat.mode,
        version: chat.conversationVersion,
      ),
      builder: (context, state, _) {
        if (_version != state.version) {
          _version = state.version;
          _followLatest = true;
          _jumpVisible = false;
          _queueScrollUpdate();
        }
        final bottomPadding = MediaQuery.paddingOf(context).bottom;
        final roomHeight =
            MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom;
        return AppScreenScaffold(
          maxContentWidth: 880,
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 10),
          child: Column(
            children: [
              ChatHeader(
                userName: userName,
                mode: state.mode,
                historyOff: state.historyOff,
                isBusy: state.isBusy,
                onModeChanged: chat.setMode,
                onOpenHistory: () => _openPage(const ChatHistoryScreen()),
                onOpenSettings: () => _openPage(const SettingsScreen()),
                onNewChat: () => _newChat(chat),
                onCopyChat: state.hasMessages ? () => _copyChat(chat) : null,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: state.hasMessages
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child:
                                NotificationListener<ScrollMetricsNotification>(
                                  onNotification: (notice) {
                                    if (notice.depth == 0) _queueScrollUpdate();
                                    return false;
                                  },
                                  child: ChatMessages(
                                    key: ValueKey(state.version),
                                    scrollController: _scroll,
                                    onRetry: _retry,
                                    onUseDraft: _useDraft,
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
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : ChatEmptyState(
                        mode: state.mode,
                        apiConfigured: state.isConfigured,
                        showStarterPrompts: settings.showStarterPrompts,
                        onSuggestionTap: _useDraft,
                        onConnect: () => _openPage(const SettingsScreen()),
                      ),
              ),
              const SizedBox(height: 8),
              BottomChatField(
                key: _composer,
                conversationVersion: state.version,
                isBusy: state.isBusy,
                isGenerating: state.isGenerating,
                canStop: state.canStop,
                compact: roomHeight < 380,
              ),
            ],
          ),
        );
      },
    );
  }
}
