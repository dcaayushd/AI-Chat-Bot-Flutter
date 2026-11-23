import 'dart:async';
import 'dart:collection';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/apis/gemini_config.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/chat_repository.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/utilities/chat_transcript.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    GeminiClient? gemini,
    ChatRepository? repository,
    bool Function()? shouldSaveHistory,
    String? developmentKey,
  }) : _gemini = gemini ?? GeminiClient(),
       _repository = repository ?? ChatRepository(),
       _shouldSaveHistory = shouldSaveHistory ?? _alwaysSave,
       _developmentKey = developmentKey == null
           ? GeminiConfig.developmentKey
           : (GeminiConfig.normalizeKey(developmentKey) ?? '');

  static const maxPromptLength = 24000;
  static const _maxContextLength = 80000;
  static const _maxContextMessages = 24;
  static const _streamUpdateInterval = Duration(milliseconds: 50);
  static const _uuid = Uuid();

  final GeminiClient _gemini;
  final ChatRepository _repository;
  final bool Function() _shouldSaveHistory;
  final String _developmentKey;

  final List<Message> _messages = [];
  final Map<String, ChatImage> _sessionImages = {};
  _Reply? _reply;
  String _sessionKey = '';
  String _chatId = '';
  String? _generationError;
  String? _storageError;
  ChatMode _mode = ChatMode.general;
  int _conversationVersion = 0;
  bool _changingConversation = false;
  bool _sessionOnly = false;
  bool _disposed = false;

  static bool _alwaysSave() => true;

  String get model => _gemini.model;
  String get _apiKey => _sessionKey.isEmpty ? _developmentKey : _sessionKey;
  bool get isConfigured => _apiKey.isNotEmpty;
  bool get hasSessionKey => _sessionKey.isNotEmpty;
  ChatMode get mode => _mode;
  String get currentChatId => _chatId;
  int get conversationVersion => _conversationVersion;
  bool get hasMessages => _messages.isNotEmpty;
  bool get isBusy => _reply != null || _changingConversation;
  bool get isGenerating => _reply != null;
  bool get canStop => _reply?.canStop ?? false;
  bool get historyOff => _sessionOnly || !_shouldSaveHistory();
  String? get generationError => _generationError;
  String? get storageError => _storageError;
  Message? get streamingReply => _reply?.draft;
  List<Message> get messages => UnmodifiableListView(_messages);
  bool get hasUnansweredPrompt =>
      !isBusy && _messages.lastOrNull?.role == Role.user;

  int get visibleMessageCount {
    final reply = _reply;
    return reply?.draft != null && reply?.previousAnswer == null
        ? _messages.length + 1
        : _messages.length;
  }

  Message visibleMessageAt(int index) {
    final draft = streamingReply;
    if (draft != null && index == visibleMessageCount - 1) return draft;
    return _messages[index];
  }

  void setSessionKey(String key) {
    final value = GeminiConfig.normalizeKey(key);
    if (value == null && key.trim().isNotEmpty) {
      throw const ChatException('Enter a valid Gemini API key.');
    }
    _sessionKey = value ?? '';
    _notify();
  }

  void setMode(ChatMode mode) {
    if (isBusy || _mode == mode) return;
    _mode = mode;
    _notify();
  }

  Future<void> send(String text, {List<ChatImage> images = const []}) async {
    _checkReady();
    final prompt = text.trim();
    if (prompt.isEmpty && images.isEmpty) return;
    if (prompt.length > maxPromptLength) {
      throw const ChatException('Keep your message under 24,000 characters.');
    }
    if (images.length > ChatImage.maxCount ||
        images.fold(0, (total, image) => total + image.bytes.length) >
            ChatImage.maxRequestBytes) {
      throw const ChatException(
        'Attach up to 4 images totaling 10 MB or less.',
      );
    }

    if (_chatId.isEmpty) _chatId = _uuid.v4();
    final imageKeys = <String>[];
    for (final image in images) {
      final key = _repository.imageKey(_chatId, _uuid.v4());
      _sessionImages[key] = image;
      imageKeys.add(key);
    }
    _messages.add(
      Message(
        messageId: _uuid.v4(),
        chatId: _chatId,
        role: Role.user,
        text: prompt.isEmpty ? 'Describe the attached images.' : prompt,
        imagesUrls: imageKeys,
        timeSent: DateTime.now(),
      ),
    );
    await _generate(_messages.length - 1, savePrompt: true);
  }

  Future<void> retryLastReply() async {
    _checkReady();
    final index = _messages.lastIndexWhere(
      (message) => message.role == Role.user,
    );
    if (index == -1) return;
    await _generate(index, savePrompt: false);
  }

  void _checkReady() {
    if (isBusy) {
      throw const ChatException('Wait for the current chat action to finish.');
    }
    if (!isConfigured) {
      throw const ChatException(
        'Set API_KEY in .env for local development or add a session key in Settings.',
      );
    }
  }

  Future<void> _generate(int promptIndex, {required bool savePrompt}) async {
    final answerIndex = promptIndex + 1;
    final previous = answerIndex < _messages.length
        ? _messages[answerIndex]
        : null;
    final reply = _Reply(
      draft: Message(
        messageId: _uuid.v4(),
        chatId: _chatId,
        role: Role.assistant,
        text: '',
        timeSent: DateTime.now(),
      ),
      previousAnswer: previous,
    );
    _reply = reply;
    _generationError = null;
    if (historyOff) _sessionOnly = true;
    final key = _apiKey;
    final mode = _mode;
    _notify();

    var status = ReplyStatus.complete;
    try {
      if (savePrompt) await _persist();
      if (!reply.stopped) {
        final turns = await _contextFor(promptIndex, reply);
        if (!reply.stopped) {
          final iterator = StreamIterator<GeminiChunk>(
            _gemini.streamReply(
              apiKey: key,
              mode: mode,
              turns: turns,
              abort: reply.abort.future,
            ),
          );
          reply.iterator = iterator;
          while (await iterator.moveNext() && !reply.stopped) {
            final chunk = iterator.current;
            if (chunk.truncated) status = ReplyStatus.truncated;
            if (chunk.text.isEmpty) continue;
            reply.text.write(chunk.text);
            _publishChunk(reply);
          }
        }
      }
      if (reply.stopped) {
        status = ReplyStatus.stopped;
      } else if (reply.text.toString().trim().isEmpty) {
        _generationError = status == ReplyStatus.truncated
            ? 'Gemini reached its length limit before writing a reply. Try a narrower prompt.'
            : 'Gemini returned an empty reply. Try again.';
        status = ReplyStatus.interrupted;
      }
    } catch (error) {
      status = reply.stopped ? ReplyStatus.stopped : ReplyStatus.interrupted;
      if (!reply.stopped) _generationError = formatChatError(error);
    } finally {
      reply.settling = true;
      reply.cancelTimer();
      reply.abortRequest();
      try {
        final text = reply.text.toString();
        // A failed regeneration leaves the previously saved answer available.
        final replacePrevious =
            status == ReplyStatus.complete || status == ReplyStatus.truncated;
        if (!_disposed &&
            text.trim().isNotEmpty &&
            (previous == null || replacePrevious)) {
          final answer = reply.draft!.withReply(text, status: status);
          if (previous == null) {
            _messages.add(answer);
          } else {
            _messages[answerIndex] = answer;
          }
          reply.draft = null;
          _notify();
          await _persist();
        }
      } finally {
        _reply = null;
        reply.done.complete();
        _notify();
      }
    }
  }

  void _publishChunk(_Reply reply) {
    if (reply.draft!.text.isEmpty) {
      reply.draft = reply.draft!.withReply(reply.text.toString());
      _notify();
      return;
    }
    reply.updateTimer ??= Timer(_streamUpdateInterval, () {
      reply.updateTimer = null;
      if (reply.stopped || _disposed) return;
      reply.draft = reply.draft!.withReply(reply.text.toString());
      _notify();
    });
  }

  void stopGeneration() {
    final reply = _reply;
    if (reply == null || !reply.canStop) return;
    reply.stop();
    _notify();
  }

  Future<List<GeminiTurn>> _contextFor(int promptIndex, _Reply reply) async {
    final turns = <GeminiTurn>[];
    var remainingText = _maxContextLength;
    var remainingImages = ChatImage.maxRequestBytes;
    final earliest = (promptIndex + 1 - _maxContextMessages).clamp(
      0,
      promptIndex,
    );
    for (
      var index = promptIndex;
      index >= earliest && !reply.stopped;
      index--
    ) {
      final message = _messages[index];
      if (index != promptIndex && message.text.length > remainingText) break;
      remainingText -= message.text.length;
      final images = <ChatImage>[];
      if (message.role == Role.user) {
        for (final reference in message.imagesUrls) {
          if (reply.stopped || remainingImages == 0) break;
          final image = await imageFor(message.chatId, reference);
          if (image == null || image.bytes.length > remainingImages) {
            if (index == promptIndex) {
              throw const ChatException(
                'An attached image is unavailable. Send the prompt with the image again.',
              );
            }
            continue;
          }
          images.add(image);
          remainingImages -= image.bytes.length;
        }
      }
      turns.add(GeminiTurn(message.role, message.text, images));
    }
    return turns.reversed
        .skipWhile((turn) => turn.role == Role.assistant)
        .toList();
  }

  Future<ChatImage?> imageFor(String chatId, String reference) async =>
      (chatId == _chatId ? _sessionImages[reference] : null) ??
      await _repository.loadImage(chatId, reference);

  Future<void> _persist() async {
    if (_disposed) return;
    if (historyOff) {
      _sessionOnly = true;
      return;
    }
    try {
      await _repository.save(
        chatId: _chatId,
        messages: _messages,
        mode: _mode,
        newImages: _sessionImages,
      );
      _sessionImages.clear();
      _storageError = null;
    } catch (_) {
      _storageError = 'This chat could not be saved to this device.';
    }
  }

  Future<void> newChat() => _changeConversation(() async {
    _useConversation();
  });

  Future<void> openChat(String chatId) async {
    if (chatId == _chatId) return;
    await _changeConversation(() async {
      final chat = _repository.getChat(chatId);
      if (chat == null) {
        throw const ChatException('This chat is no longer available.');
      }
      final messages = await _repository.loadMessages(chat);
      _useConversation(
        chatId: chatId,
        messages: messages,
        mode: ChatMode.fromName(chat.mode),
      );
    });
  }

  Future<void> deleteChat(String chatId) => _changeConversation(() async {
    await _repository.delete(chatId);
    if (_chatId == chatId) _useConversation();
  }, stopReply: _chatId == chatId);

  Future<void> clearAllChats() {
    final chatId = _chatId;
    final activeIsSaved =
        chatId.isNotEmpty && _repository.getChat(chatId) != null;
    return _changeConversation(() async {
      final hadSavedChat =
          chatId.isNotEmpty && _repository.getChat(chatId) != null;
      try {
        await _repository.clear();
      } finally {
        if (hadSavedChat && _repository.getChat(chatId) == null)
          _useConversation();
      }
    }, stopReply: activeIsSaved || !historyOff);
  }

  Future<void> _changeConversation(
    Future<void> Function() action, {
    bool stopReply = true,
  }) async {
    if (_changingConversation) {
      throw const ChatException('A chat action is already in progress.');
    }
    _changingConversation = true;
    _notify();
    try {
      final reply = _reply;
      if (reply != null && stopReply) {
        stopGeneration();
        await reply.done.future;
      }
      if (!_disposed) await action();
    } finally {
      _changingConversation = false;
      _notify();
    }
  }

  void _useConversation({
    String chatId = '',
    List<Message> messages = const [],
    ChatMode mode = ChatMode.general,
  }) {
    _chatId = chatId;
    _messages
      ..clear()
      ..addAll(messages);
    _sessionImages.clear();
    _sessionOnly = false;
    _mode = mode;
    _generationError = null;
    _storageError = null;
    _conversationVersion++;
  }

  Future<List<ChatHistory>> searchChats(
    List<ChatHistory> chats,
    String query,
  ) => _repository.search(chats, query);

  Future<void> renameChat(String chatId, String title) =>
      _repository.rename(chatId, title);

  Future<void> togglePin(String chatId) => _repository.togglePin(chatId);

  String exportCurrentChat() {
    final title = _sessionOnly
        ? null
        : _repository.getChat(_chatId)?.displayTitle;
    return transcriptAsMarkdown(title ?? 'Conversation', _messages);
  }

  Future<String> exportSavedChat(ChatHistory chat) async {
    final messages = await _repository.loadMessages(chat);
    return transcriptAsMarkdown(chat.displayTitle, messages);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reply?.stop();
    _gemini.close();
    super.dispose();
  }
}

class _Reply {
  _Reply({required this.draft, required this.previousAnswer});

  final Message? previousAnswer;
  final Completer<void> abort = Completer<void>();
  final Completer<void> done = Completer<void>();
  final StringBuffer text = StringBuffer();
  Message? draft;
  Timer? updateTimer;
  StreamIterator<GeminiChunk>? iterator;
  bool stopped = false;
  bool settling = false;

  bool get canStop => !stopped && !settling;

  void stop() {
    if (!canStop) return;
    stopped = true;
    cancelTimer();
    abortRequest();
    final stream = iterator;
    if (stream != null) unawaited(stream.cancel().onError((_, __) {}));
  }

  void abortRequest() {
    if (!abort.isCompleted) abort.complete();
  }

  void cancelTimer() {
    updateTimer?.cancel();
    updateTimer = null;
  }
}
