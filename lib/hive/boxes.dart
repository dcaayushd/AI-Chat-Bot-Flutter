import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:hive/hive.dart';

class Boxes {
  //Get the Chat History Box
  static Box<ChatHistory> getChatHistory() =>
      Hive.box<ChatHistory>(Constants.chatHistoryBox);

  //Get User Box
  static Box<UserModel> getUser() =>
      Hive.box<UserModel>(Constants.userBox);

  //Get Settings Box
  static Box<Settings> getSettings() =>
      Hive.box<Settings>(Constants.settingsBox);
}
