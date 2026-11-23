import 'dart:async';
import 'dart:collection';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/apis/gemini_config.dart';
import 'package:chatbotapp/apis/gemini_context.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/chat_repository.dart';
import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/chat_options.dart';
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
  static const _maxContinuationLength = 12000;
  static const _streamUpdateInterval = Duration(milliseconds: 50);
  static const _uuid = Uuid();

  final GeminiClient _gemini;
  final ChatRepository _repository;
  final bool Function() _shouldSaveHistory;
  final String _developmentKey;

  final List<Message> _messages = [];
  final Map<String, ChatAttachment> _sessionAttachments = {};
  _Reply? _reply;
  String _sessionKey = '';
  String _chatId = '';
  String? _title;
  String? _generationError;
  String? _storageError;
  bool _retryContinuation = false;
  ChatMode _mode = ChatMode.general;
  ChatOptions _options = const ChatOptions();
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
  ChatOptions get options => _options;
  String get currentChatId => _chatId;
  String? get title => _title;
  int get conversationVersion => _conversationVersion;
  bool get hasMessages => _messages.isNotEmpty;
  bool get isBusy => _reply != null || _changingConversation;
  bool get isChangingConversation => _changingConversation;
  bool get isGenerating => _reply != null;
  bool get canStop => _reply?.canStop ?? false;
  bool get historyOff => _sessionOnly || !_shouldSaveHistory();
  bool get canBranch =>
      hasMessages && !isBusy && !historyOff && _storageError == null;
  String? get generationError => _generationError;
  String? get storageError => _storageError;
  Message? get streamingReply => _reply?.draft;
  List<Message> get messages => UnmodifiableListView(_messages);
  bool get hasUnansweredPrompt =>
      !isBusy && _messages.lastOrNull?.role == Role.user;
  bool get canContinueLastReply {
    if (isBusy || _messages.length < 2) return false;
    final last = _messages.last;
    return last.role == Role.assistant &&
        last.status != ReplyStatus.complete &&
        _messages[_messages.length - 2].role == Role.user;
  }

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

  Future<void> updateOptions(ChatOptions options) async {
    _checkIdle();
    final value = options.normalized();
    if (_options == value) return;
    if (!historyOff && hasMessages && _repository.getChat(_chatId) != null) {
      await _changeConversation(() async {
        await _repository.saveOptions(_chatId, value);
        _options = value;
      });
    } else {
      _options = value;
      _notify();
    }
  }

  Future<void> send(
    String text, {
    List<ChatImage> images = const [],
    List<ChatDocument> documents = const [],
  }) async {
    _checkReady();
    final prompt = _validatePrompt(text);
    final attachments = <ChatAttachment>[...images, ...documents];
    if (prompt.isEmpty && attachments.isEmpty) return;
    if (attachments.length > ChatAttachment.maxCount ||
        documents.length > ChatDocument.maxCount ||
        attachments.fold(0, (total, file) => total + file.bytes.length) >
            ChatAttachment.maxRequestBytes) {
      throw const ChatException(
        'Attach up to 4 files, including up to 2 documents, totaling 10 MB or less.',
      );
    }

    if (_chatId.isEmpty) _chatId = _uuid.v4();
    final imageKeys = <String>[];
    final documentKeys = <String>[];
    for (final attachment in attachments) {
      final key = _repository.attachmentKey(_chatId, _uuid.v4());
      _sessionAttachments[key] = attachment;
      (attachment is ChatImage ? imageKeys : documentKeys).add(key);
    }
    _messages.add(
      Message(
        messageId: _uuid.v4(),
        chatId: _chatId,
        role: Role.user,
        text: prompt.isEmpty
            ? (documents.isEmpty
                  ? 'Describe the attached images.'
                  : 'Summarize the attached files.')
            : prompt,
        imagesUrls: imageKeys,
        documentRefs: documentKeys,
        timeSent: DateTime.now(),
      ),
    );
    _title ??= ChatHistory.formatTitle(_messages.first.text);
    await _generate(_messages.length - 1, savePrompt: true);
  }

  Future<void> retryLastReply({bool afterError = false}) async {
    _checkReady();
    if (afterError && _retryContinuation && canContinueLastReply) {
      await continueLastReply();
      return;
    }
    final index = _messages.lastIndexWhere(
      (message) => message.role == Role.user,
    );
    if (index == -1) return;
    await _generate(index, savePrompt: false);
  }

  Future<void> continueLastReply() async {
    _checkReady();
    if (!canContinueLastReply) return;
    await _generate(_messages.length - 2, savePrompt: false, continuing: true);
  }

  Future<void> restoreReply(String messageId, ReplyRevision revision) async {
    _checkIdle();
    final last = _messages.lastOrNull;
    if (last == null ||
        last.messageId != messageId ||
        !last.previousReplies.contains(revision)) {
      throw const ChatException(
        'This reply version is no longer available to restore.',
      );
    }
    await _changeConversation(() async {
      _messages[_messages.length - 1] = last.selectRevision(revision);
      _generationError = null;
      _retryContinuation = false;
      await _persist();
    });
  }

  String _validatePrompt(String text) {
    final prompt = text.trim();
    if (prompt.length > maxPromptLength) {
      throw const ChatException('Keep your message under 24,000 characters.');
    }
    return prompt;
  }

  void _checkIdle() {
    if (isBusy) {
      throw const ChatException('Wait for the current chat action to finish.');
    }
  }

  void _checkReady() {
    _checkIdle();
    if (!isConfigured) {
      throw const ChatException(
        'Set API_KEY in .env for local development or add a session key in Settings.',
      );
    }
  }

  Future<void> _generate(
    int promptIndex, {
    required bool savePrompt,
    bool continuing = false,
  }) async {
    final answerIndex = _messages.length > promptIndex + 1
        ? _messages.length - 1
        : promptIndex + 1;
    final previous = answerIndex < _messages.length
        ? _messages[answerIndex]
        : null;
    final prefix = continuing ? previous!.text : '';
    final reply = _Reply(
      draft: Message(
        messageId: previous?.messageId ?? _uuid.v4(),
        chatId: _chatId,
        role: Role.assistant,
        text: prefix,
        timeSent: DateTime.now(),
        contextLimited: continuing && previous!.contextLimited,
      ),
      previousAnswer: previous,
      prefix: prefix,
    );
    _reply = reply;
    _generationError = null;
    _retryContinuation = false;
    if (historyOff) _sessionOnly = true;
    final key = _apiKey;
    final mode = _mode;
    final options = _options;
    _notify();

    var status = ReplyStatus.complete;
    try {
      if (savePrompt) await _persist();
      if (!reply.stopped) {
        final tailStart = (prefix.length - _maxContinuationLength).clamp(
          0,
          prefix.length,
        );
        final context = await GeminiContext.build(
          messages: _messages,
          promptIndex: promptIndex,
          loadAttachment: attachmentFor,
          stopped: () => reply.stopped,
          suffix: continuing
              ? [
                  GeminiTurn(Role.assistant, prefix.substring(tailStart)),
                  const GeminiTurn(
                    Role.user,
                    'Continue the preceding reply from its ending. Begin with the next text, preserving spacing and formatting. Avoid repeating earlier text.',
                  ),
                ]
              : const [],
        );
        reply.contextLimited =
            context.limited || tailStart > 0 || reply.draft!.contextLimited;
        if (!reply.stopped) {
          final iterator = StreamIterator<GeminiChunk>(
            _gemini.streamReply(
              apiKey: key,
              mode: mode,
              turns: context.turns,
              abort: reply.abort.future,
              options: options,
            ),
          );
          reply.iterator = iterator;
          while (await iterator.moveNext() && !reply.stopped) {
            final chunk = iterator.current;
            if (chunk.truncated) status = ReplyStatus.truncated;
            if (chunk.text.isNotEmpty) {
              reply.delta.write(chunk.text);
              _publishChunk(reply);
            }
            if (chunk.finished) break;
          }
        }
      }
      if (reply.stopped) {
        status = ReplyStatus.stopped;
      } else if (reply.delta.toString().trim().isEmpty) {
        _generationError = status == ReplyStatus.truncated
            ? 'Gemini reached its length limit before writing a reply. Try a narrower prompt.'
            : continuing
            ? 'Gemini did not add to this reply. Try again.'
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
      reply.cancelStream();
      _retryContinuation = continuing && _generationError != null;
      try {
        // Preserve a usable existing reply when a regeneration fails.
        final replacePrevious =
            continuing ||
            status == ReplyStatus.complete ||
            status == ReplyStatus.truncated;
        if (!_disposed &&
            reply.delta.toString().trim().isNotEmpty &&
            (previous == null || replacePrevious)) {
          final outcome = reply.draft!.copyWith(
            text: reply.fullText,
            status: status,
            contextLimited: reply.contextLimited,
          );
          final answer = previous?.selectRevision(outcome.revision) ?? outcome;
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
    if (!reply.published) {
      reply.published = true;
      reply.draft = reply.draft!.copyWith(text: reply.fullText);
      _notify();
      return;
    }
    reply.updateTimer ??= Timer(_streamUpdateInterval, () {
      reply.updateTimer = null;
      if (reply.stopped || _disposed) return;
      reply.draft = reply.draft!.copyWith(text: reply.fullText);
      _notify();
    });
  }

  void stopGeneration() {
    final reply = _reply;
    if (reply == null || !reply.canStop) return;
    reply.stop();
    _notify();
  }

  Future<ChatAttachment?> attachmentFor(
    String chatId,
    String reference,
  ) async =>
      (chatId == _chatId ? _sessionAttachments[reference] : null) ??
      await _repository.loadAttachment(chatId, reference);

  Future<ChatImage?> imageFor(String chatId, String reference) async {
    final attachment = await attachmentFor(chatId, reference);
    return attachment is ChatImage ? attachment : null;
  }

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
        options: _options,
        newAttachments: _sessionAttachments,
      );
      _sessionAttachments.clear();
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
        title: chat.displayTitle,
        messages: messages,
        mode: ChatMode.fromName(chat.mode),
        options: ChatOptions.fromMap(chat.options),
      );
    });
  }

  Future<void> branchFrom(String messageId) async {
    final index = _branchIndex(messageId);
    await _branchMessages(_messages.take(index + 1));
  }

  Future<void> editPromptInBranch(String messageId, String text) async {
    _checkReady();
    final index = _branchIndex(messageId);
    final selected = _messages[index];
    final prompt = _validatePrompt(text);
    if (selected.role != Role.user || prompt.isEmpty) {
      throw const ChatException('Enter a prompt for the new branch.');
    }
    final branchId = await _branchMessages([
      ..._messages.take(index),
      selected.copyWith(text: prompt, timeSent: DateTime.now()),
    ]);
    if (!_disposed && _chatId == branchId && !isBusy) {
      await _generate(index, savePrompt: false);
    }
  }

  int _branchIndex(String messageId) {
    if (!canBranch || _repository.getChat(_chatId) == null) {
      throw const ChatException('Branching requires a saved conversation.');
    }
    final index = _messages.indexWhere(
      (message) => message.messageId == messageId,
    );
    if (index == -1) {
      throw const ChatException('This message is no longer available.');
    }
    return index;
  }

  Future<String> _branchMessages(Iterable<Message> prefix) async {
    final chatId = _uuid.v4();
    await _changeConversation(() async {
      final mode = _mode;
      final options = _options;
      final source = _title ?? 'Conversation';
      final title = 'Branch · ${String.fromCharCodes(source.runes.take(68))}';
      final messages = await _repository.saveBranch(
        chatId: chatId,
        title: title,
        prefix: prefix,
        mode: mode,
        options: options,
      );
      if (!_disposed) {
        _useConversation(
          chatId: chatId,
          title: title,
          messages: messages,
          mode: mode,
          options: options,
        );
      }
    });
    return chatId;
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
    String? title,
    List<Message> messages = const [],
    ChatMode mode = ChatMode.general,
    ChatOptions options = const ChatOptions(),
  }) {
    _chatId = chatId;
    _title = title;
    _messages
      ..clear()
      ..addAll(messages);
    _sessionAttachments.clear();
    _sessionOnly = false;
    _mode = mode;
    _options = options;
    _generationError = null;
    _retryContinuation = false;
    _storageError = null;
    _conversationVersion++;
  }

  Future<List<ChatHistory>> searchChats(
    List<ChatHistory> chats,
    String query,
  ) => _repository.search(chats, query);

  Future<void> renameChat(String chatId, String title) async {
    await _repository.rename(chatId, title);
    if (_chatId == chatId) {
      _title = _repository.getChat(chatId)?.displayTitle;
      _notify();
    }
  }

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
  _Reply({
    required this.draft,
    required this.previousAnswer,
    required this.prefix,
  });

  final Message? previousAnswer;
  final String prefix;
  final Completer<void> abort = Completer<void>();
  final Completer<void> done = Completer<void>();
  final StringBuffer delta = StringBuffer();
  bool published = false;
  bool contextLimited = false;
  Message? draft;
  Timer? updateTimer;
  StreamIterator<GeminiChunk>? iterator;
  bool stopped = false;
  bool settling = false;

  String get fullText => '$prefix$delta';
  bool get canStop => !stopped && !settling;

  void stop() {
    if (!canStop) return;
    stopped = true;
    cancelTimer();
    abortRequest();
    cancelStream();
  }

  void cancelStream() {
    final stream = iterator;
    iterator = null;
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
