import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:chatbotapp/apis/api_service.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  // List of Messages
  List<Message> _inChatMessages = [];

  // Page Controller
  final PageController _pageController = PageController();

  // Images File List

  List<XFile>? _imagesFileList = [];

  // ? Index of the current Screen

  int _currentIndex = 0;

  // Current ChatId
  String _currentChatId = '';

  // Initialize generative Model
  GenerativeModel? _model;

  // Initialize Text Model
  GenerativeModel? _textModel;

  // Initialize Vision Model
  GenerativeModel? _visionModel;

  // Current Model
  String _modelType = 'gemini-pro';

  // Loading Bool
  bool _isLoading = false;

  // Getters
  List<Message> get inChatMessages => _inChatMessages;
  PageController get pageController => _pageController;
  List<XFile>? get imagesFileList => _imagesFileList;
  int get currentIndex => _currentIndex;
  String get currentChatId => _currentChatId;

  GenerativeModel? get model => _model;
  GenerativeModel? get textModel => _textModel;
  GenerativeModel? get visionModel => _visionModel;

  String get modelType => _modelType;
  bool get isLoading => _isLoading;

  // Setters
  //Set inChatMessages
  Future<void> setInChatMessages({required String chatId}) async {
    // Get Messages from Hive Database
    final messagesFromDb = await loadMessagesFromDB(chatId: chatId);

    for (var message in messagesFromDb) {
      if (_inChatMessages.contains(message)) {
        log('Message Already Exists!');
        continue;
      }
      _inChatMessages.add(message);
    }
    notifyListeners();
  }

  // Load the Messages from Database
  Future<List<Message>> loadMessagesFromDB({required String chatId}) async {
    // open the box of this chatId
    await Hive.openBox('${Constants.chatMessagesBox}$chatId');

    final messageBox = Hive.box('${Constants.chatMessagesBox}$chatId');

    final newData = messageBox.keys.map((e) {
      final message = messageBox.get(e);
      final messageData = Message.fromMap(Map<String, dynamic>.from(message));
      return messageData;
    }).toList();
    notifyListeners();
    return newData;
  }

  // Set File List
  void setImagesFileList({required List<XFile> listValue}) {
    _imagesFileList = listValue;
    notifyListeners();
  }

  // Set the Current Model
  String setCurrentModel({required String newModel}) {
    _modelType = newModel;
    notifyListeners();
    return newModel;
  }

  // Function to set the model based on bool -isTextOnly
  Future<void> setModel({required bool isTextOnly}) async {
    if (isTextOnly) {
      _model = _textModel ??
          GenerativeModel(
            model: setCurrentModel(newModel: 'gemini-pro'),
            apiKey: ApiService.apiKey,
          );
    } else {
      _model = _visionModel ??
          GenerativeModel(
            model: setCurrentModel(newModel: 'gemini-pro-vision'),
            apiKey: ApiService.apiKey,
          );
    }
    notifyListeners();
  }

  // Set current Page index
  void setCurrentIndex({required int newIndex}) {
    _currentIndex = newIndex;
    notifyListeners();
  }

  // Set current chatId
  void setCurrentChatId({required String newChatId}) {
    _currentChatId = newChatId;
    notifyListeners();
  }

  // Set Loading
  void setLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  // Send Message to gemini and get the streamed response
  Future<void> sentMessage({
    required String message,
    required bool isTextOnly,
  }) async {
    // Set the model
    await setModel(isTextOnly: isTextOnly);

    // Set the loading
    setLoading(value: true);

    // Get the chatId
    String chatId = getChatId();

    // List of history messages
    List<Content> history = [];

    // Get the chat history
    history = await getHistory(chatId: chatId);

    // Get the imagesUrls
    List<String> imagesUrls = getImagesUrls(isTextOnly: isTextOnly);

    // user message id
    final userMessageId = const Uuid().v4();

    // user message
    final userMessage = Message(
      messageId: userMessageId,
      chatId: chatId,
      role: Role.user,
      message: StringBuffer(message),
      imagesUrls: imagesUrls,
      timeSent: DateTime.now(),
    );

    // add this message to the list on inChatMessages
    _inChatMessages.add(userMessage);
    notifyListeners();

    if (currentChatId.isEmpty) {
      setCurrentChatId(newChatId: chatId);
    }

    // send the message to the model and wait for the response
    await sendMessageAndWaitForResponse(
      message: message,
      chatId: chatId,
      isTextOnly: isTextOnly,
      history: history,
      userMessage: userMessage,
    );
  }

  // send message to the model and wait for the response
  Future<void> sendMessageAndWaitForResponse({
    required String message,
    required String chatId,
    required bool isTextOnly,
    required List<Content> history,
    required Message userMessage,
  }) async {
    // start the chat session - only send history is its text-only
    final chatSession = _model!.startChat(
      history: history.isEmpty || !isTextOnly ? null : history,
    );
    // Get content
    final content = await getContent(
      message: message,
      isTextOnly: isTextOnly,
    );

   // Assistant messageId
    final modelMessageId = const Uuid().v4();

    // Assistant Message
    final assistanceMessage = userMessage.copyWith(
      messageId: modelMessageId,
      role: Role.assistant,
      message: StringBuffer(),
      timeSent: DateTime.now(),
    );

    // Add this message to the list on inChatMessages
    _inChatMessages.add(assistanceMessage);
    notifyListeners();

    // Wait for stream response
    chatSession.sendMessageStream(content).asyncMap((event) {
      return event;
    }).listen((event) {
      _inChatMessages
          .firstWhere((element) =>
              element.messageId == assistanceMessage.messageId &&
              element.role.name == Role.assistant.name)
          .message
          .write(event.text);
      notifyListeners();
    }, onDone: () {
      // Save Message to Hive DB

      //Set Loading to false
      setLoading(value: false);
    }).onError((error, stackTrace) {
      // set loading
      setLoading(value: false);
    });
  }

  // get content
  Future<Content> getContent({
    required message,
    required bool isTextOnly,
  }) async {
    if (isTextOnly) {
      // Generate text from text-only input
      return Content.text(message);
    } else {
      // Generate image from text and image input
      final imageFutures = _imagesFileList
          ?.map((imageFile) => imageFile.readAsBytes())
          .toList(growable: false);
      final imageBytes = await Future.wait(imageFutures!);
      final prompt = TextPart(message);
      final imageParts = imageBytes
          .map((bytes) => DataPart('image/jpg', Uint8List.fromList(bytes)))
          .toList();

      return Content.model([prompt, ...imageParts]);
    }
  }

  // get the imagesUrls
  List<String> getImagesUrls({required bool isTextOnly}) {
    List<String> imagesUrls = [];
    if (!isTextOnly && imagesFileList != null) {
      for (var image in imagesFileList!) {
        imagesUrls.add(image.path);
      }
    }
    return imagesUrls;
  }

  // get the chat history
  Future<List<Content>> getHistory({required String chatId}) async {
    List<Content> history = [];
    if (currentChatId.isNotEmpty) {
      await setInChatMessages(chatId: chatId);

      for (var message in inChatMessages) {
        if (message.role == Role.user) {
          history.add(
            Content.text(message.message.toString()),
          );
        } else {
          history.add(
            Content.model(
              [
                TextPart(message.message.toString()),
              ],
            ),
          );
        }
      }
    }
    return history;
  }

  // get the chatId
  String getChatId() {
    if (currentChatId.isEmpty) {
      return const Uuid().v4();
    } else {
      return currentChatId;
    }
  }

  // Init Hive Box
  static initHive() async {
    final dir = await path.getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.initFlutter(Constants.geminiDB);

    //Register Adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatHistoryAdapter());

      // Open the Chat History Box
      Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());

      // Open the Chat History Box
      Hive.openBox<UserModel>(Constants.userBox);
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SettingsAdapter());

      // Open the Chat History Box
      Hive.openBox<Settings>(Constants.settingsBox);
    }
  }
}
