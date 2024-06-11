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
