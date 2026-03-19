import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:chatbotapp/apis/api_service.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  static const _requestTimeout = Duration(seconds: 40);

  final List<Message> _inChatMessages = [];
  List<XFile>? _imagesFileList = [];
  String _currentChatId = '';
  GenerativeModel? _model;
  GenerativeModel? _textModel;
  GenerativeModel? _visionModel;
  String _modelType = Constants.geminiTextModel;
  bool _isLoading = false;

  List<Message> get inChatMessages => _inChatMessages;
  List<XFile>? get imagesFileList => _imagesFileList;
  String get currentChatId => _currentChatId;
  GenerativeModel? get model => _model;
  GenerativeModel? get textModel => _textModel;
  GenerativeModel? get visionModel => _visionModel;
  String get modelType => _modelType;
  bool get isLoading => _isLoading;
  bool get hasMessages => _inChatMessages.isNotEmpty;

  int get messageCount => _inChatMessages.length;

  Future<void> setInChatMessages({required String chatId}) async {
    final messagesFromDB = await loadMessagesFromDB(chatId: chatId);
    _inChatMessages
      ..clear()
      ..addAll(messagesFromDB);
    notifyListeners();
  }

  Future<List<Message>> loadMessagesFromDB({required String chatId}) async {
    await Hive.openBox('${Constants.chatMessagesBox}$chatId');
    final messageBox = Hive.box('${Constants.chatMessagesBox}$chatId');
    final newData = messageBox.keys.map((e) {
      final message = messageBox.get(e);
      return Message.fromMap(Map<String, dynamic>.from(message));
    }).toList();
    return newData;
  }

  void setImagesFileList({required List<XFile> listValue}) {
    _imagesFileList = listValue;
    notifyListeners();
  }

  void removeImageAt(int index) {
    if (_imagesFileList == null || index >= _imagesFileList!.length) {
      return;
    }
    final updated = List<XFile>.from(_imagesFileList!)..removeAt(index);
    _imagesFileList = updated;
    notifyListeners();
  }

  void clearDraft() {
    _imagesFileList = [];
    notifyListeners();
  }

  String setCurrentModel({required String newModel}) {
    _modelType = newModel;
    notifyListeners();
    return newModel;
  }

  Future<void> setModel({required bool isTextOnly}) async {
    final modelName =
        isTextOnly ? Constants.geminiTextModel : Constants.geminiVisionModel;
    setCurrentModel(newModel: modelName);
    final generationConfig = GenerationConfig(
      temperature: isTextOnly ? 0.45 : 0.35,
      topP: 0.9,
      topK: 32,
      maxOutputTokens: 2048,
    );
    final systemInstruction = Content.system(
      Constants.assistantSystemInstruction,
    );

    if (isTextOnly) {
      _textModel ??= GenerativeModel(
        model: modelName,
        apiKey: ApiService.apiKey,
        generationConfig: generationConfig,
        systemInstruction: systemInstruction,
      );
      _model = _textModel;
    } else {
      _visionModel ??= GenerativeModel(
        model: modelName,
        apiKey: ApiService.apiKey,
        generationConfig: generationConfig,
        systemInstruction: systemInstruction,
      );
      _model = _visionModel;
    }
    notifyListeners();
  }

  void setCurrentChatId({required String newChatId}) {
    _currentChatId = newChatId;
    notifyListeners();
  }

  void setLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> deleteChatMessages({required String chatId}) async {
    final storedImagePaths = await _storedImagePathsForChat(chatId: chatId);
    await _deleteImageFiles(storedImagePaths);

    if (!Hive.isBoxOpen('${Constants.chatMessagesBox}$chatId')) {
      await Hive.openBox('${Constants.chatMessagesBox}$chatId');
      await Hive.box('${Constants.chatMessagesBox}$chatId').clear();
      await Hive.box('${Constants.chatMessagesBox}$chatId').close();
    } else {
      await Hive.box('${Constants.chatMessagesBox}$chatId').clear();
      await Hive.box('${Constants.chatMessagesBox}$chatId').close();
    }

    if (currentChatId.isNotEmpty) {
      if (currentChatId == chatId) {
        setCurrentChatId(newChatId: '');
        _inChatMessages.clear();
        notifyListeners();
      }
    }
  }

  Future<void> clearAllChats() async {
    final historyBox = Boxes.getChatHistory();
    final chatIds = historyBox.keys.cast<String>().toList(growable: false);

    for (final chatId in chatIds) {
      await deleteChatMessages(chatId: chatId);
    }

    await historyBox.clear();
    _inChatMessages.clear();
    _currentChatId = '';
    notifyListeners();
  }

  Future<void> prepareChatRoom({
    required bool isNewChat,
    required String chatID,
  }) async {
    if (!isNewChat) {
      final chatHistory = await loadMessagesFromDB(chatId: chatID);
      _inChatMessages.clear();
      for (var message in chatHistory) {
        _inChatMessages.add(message);
      }
      setCurrentChatId(newChatId: chatID);
    } else {
      _inChatMessages.clear();
      setCurrentChatId(newChatId: chatID);
    }
    clearDraft();
    notifyListeners();
  }

  Future<void> sentMessage({
    required String message,
    required bool isTextOnly,
    List<XFile>? draftImages,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return;
    }

    await setModel(isTextOnly: isTextOnly);
    setLoading(value: true);
    String chatId = getChatId();
    final imageFiles = isTextOnly
        ? const <XFile>[]
        : await _storeDraftImages(
            chatId: chatId,
            draftImages: draftImages,
          );
    List<Content> history = [];
    history = await getHistory(chatId: chatId);
    List<String> imagesUrls = getImagesUrls(imageFiles: imageFiles);
    final messagesBox =
        await Hive.openBox('${Constants.chatMessagesBox}$chatId');
    final userMessageId = messagesBox.keys.length;
    final assistantMessageId = messagesBox.keys.length + 1;

    final userMessage = Message(
      messageId: userMessageId.toString(),
      chatId: chatId,
      role: Role.user,
      message: StringBuffer(trimmedMessage),
      imagesUrls: imagesUrls,
      timeSent: DateTime.now(),
    );

    _inChatMessages.add(userMessage);
    notifyListeners();

    if (currentChatId.isEmpty) {
      setCurrentChatId(newChatId: chatId);
    }

    await sendMessageAndWaitForResponse(
      message: trimmedMessage,
      chatId: chatId,
      isTextOnly: isTextOnly,
      imageFiles: imageFiles,
      history: history,
      userMessage: userMessage,
      modelMessageId: assistantMessageId.toString(),
      messagesBox: messagesBox,
    );
  }

  // send message to the model and wait for the response
  Future<void> sendMessageAndWaitForResponse({
    required String message,
    required String chatId,
    required bool isTextOnly,
    required List<XFile> imageFiles,
    required List<Content> history,
    required Message userMessage,
    required String modelMessageId,
    required Box messagesBox,
  }) async {
    final chatSession = _model!.startChat(
      history: history.isEmpty || !isTextOnly ? null : history,
    );
    final content = await getContent(
      message: message,
      isTextOnly: isTextOnly,
      imageFiles: imageFiles,
    );
    final assistantMessage = userMessage.copyWith(
      messageId: modelMessageId,
      role: Role.assistant,
      message: StringBuffer(),
      timeSent: DateTime.now(),
    );
    _inChatMessages.add(assistantMessage);
    notifyListeners();

    try {
      await _requestAssistantResponse(
        chatSession: chatSession,
        content: content,
        assistantMessage: assistantMessage,
      );
      await saveMessagesToDB(
        chatID: chatId,
        userMessage: userMessage,
        assistantMessage: assistantMessage,
        messagesBox: messagesBox,
      );
    } catch (error, stackTrace) {
      _removeAssistantDraft(assistantMessage);
      notifyListeners();
      Error.throwWithStackTrace(
        StateError(formatChatError(error)),
        stackTrace,
      );
    } finally {
      if (messagesBox.isOpen) {
        await messagesBox.close();
      }
      setLoading(value: false);
    }
  }

  Future<void> _requestAssistantResponse({
    required ChatSession chatSession,
    required Content content,
    required Message assistantMessage,
  }) async {
    try {
      final response =
          await chatSession.sendMessage(content).timeout(_requestTimeout);
      _applyAssistantText(
        assistantMessage: assistantMessage,
        text: response.text?.trim() ?? '',
      );
    } catch (error) {
      if (!shouldRetryRequest(error)) {
        rethrow;
      }

      final retryResponse =
          await chatSession.sendMessage(content).timeout(_requestTimeout);
      _applyAssistantText(
        assistantMessage: assistantMessage,
        text: retryResponse.text?.trim() ?? '',
      );
    }
  }

  void _removeAssistantDraft(Message assistantMessage) {
    _inChatMessages.removeWhere(
      (element) =>
          element.messageId == assistantMessage.messageId &&
          element.role == Role.assistant &&
          element.message.isEmpty,
    );
  }

  void _applyAssistantText({
    required Message assistantMessage,
    required String text,
  }) {
    if (text.isEmpty) {
      throw StateError('No response returned. Try again.');
    }

    assistantMessage.message = StringBuffer(text);
    notifyListeners();
  }

  // save messages to hive db
  Future<void> saveMessagesToDB({
    required String chatID,
    required Message userMessage,
    required Message assistantMessage,
    required Box messagesBox,
  }) async {
    final settings =
        Boxes.getSettings().isNotEmpty ? Boxes.getSettings().getAt(0) : null;
    final saveChatHistory = settings?.saveChatHistory ?? true;

    if (!saveChatHistory) {
      return;
    }

    await messagesBox.add(userMessage.toMap());
    await messagesBox.add(assistantMessage.toMap());
    final chatHistoryBox = Boxes.getChatHistory();
    final chatHistory = ChatHistory(
      chatId: chatID,
      prompt: userMessage.message.toString(),
      response: assistantMessage.message.toString(),
      imagesUrls: userMessage.imagesUrls,
      timestamp: DateTime.now(),
    );
    await chatHistoryBox.put(chatID, chatHistory);
  }

  Future<Content> getContent({
    required String message,
    required bool isTextOnly,
    required List<XFile> imageFiles,
  }) async {
    if (isTextOnly) {
      return Content.text(message);
    } else {
      final imageBytes = await Future.wait(
        imageFiles.map((imageFile) => imageFile.readAsBytes()),
      );
      final prompt = TextPart(message);
      final imageParts = imageBytes
          .map((bytes) => DataPart('image/jpeg', Uint8List.fromList(bytes)))
          .toList();

      return Content.multi([prompt, ...imageParts]);
    }
  }

  List<String> getImagesUrls({
    required List<XFile> imageFiles,
  }) {
    return imageFiles.map((image) => image.path).toList(growable: false);
  }

  Future<List<XFile>> _storeDraftImages({
    required String chatId,
    List<XFile>? draftImages,
  }) async {
    final images = draftImages ?? _imagesFileList ?? const <XFile>[];
    if (images.isEmpty) {
      return const <XFile>[];
    }

    final appDir = await path.getApplicationDocumentsDirectory();
    final mediaDir = Directory(
      '${appDir.path}/${Constants.geminiDB}/chat_media/$chatId',
    );
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final storedImages = <XFile>[];
    for (final imageFile in images) {
      final extension = _fileExtension(imageFile.path);
      final storedFile = File(
        '${mediaDir.path}/${const Uuid().v4()}.$extension',
      );
      await storedFile.writeAsBytes(
        await imageFile.readAsBytes(),
        flush: true,
      );
      storedImages.add(XFile(storedFile.path));
    }
    return storedImages;
  }

  String _fileExtension(String pathValue) {
    final lastDot = pathValue.lastIndexOf('.');
    if (lastDot == -1 || lastDot == pathValue.length - 1) {
      return 'jpg';
    }
    return pathValue.substring(lastDot + 1).toLowerCase();
  }

  Future<Set<String>> _storedImagePathsForChat({
    required String chatId,
  }) async {
    final imagePaths = <String>{};
    final storedMessages = await loadMessagesFromDB(chatId: chatId);
    for (final message in storedMessages) {
      imagePaths.addAll(message.imagesUrls);
    }

    if (currentChatId == chatId) {
      for (final message in _inChatMessages) {
        imagePaths.addAll(message.imagesUrls);
      }
    }

    return imagePaths;
  }

  Future<void> _deleteImageFiles(Iterable<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      if (imagePath.isEmpty) {
        continue;
      }
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<Content>> getHistory({required String chatId}) async {
    List<Content> history = [];
    if (currentChatId.isNotEmpty) {
      final messages = await loadMessagesFromDB(chatId: chatId);

      for (var message in messages) {
        if (message.role == Role.user) {
          history.add(Content.text(message.message.toString()));
        } else {
          history.add(Content.model([TextPart(message.message.toString())]));
        }
      }
    }

    return history;
  }

  String getChatId() {
    if (currentChatId.isEmpty) {
      return const Uuid().v4();
    } else {
      return currentChatId;
    }
  }

  static initHive() async {
    final dir = await path.getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.initFlutter(Constants.geminiDB);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatHistoryAdapter());
      await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    } else if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
      await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());
      await Hive.openBox<UserModel>(Constants.userBox);
    } else if (!Hive.isBoxOpen(Constants.userBox)) {
      await Hive.openBox<UserModel>(Constants.userBox);
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SettingsAdapter());
      await Hive.openBox<Settings>(Constants.settingsBox);
    } else if (!Hive.isBoxOpen(Constants.settingsBox)) {
      await Hive.openBox<Settings>(Constants.settingsBox);
    }
  }
}
