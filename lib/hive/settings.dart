import 'package:hive_flutter/hive_flutter.dart';

part 'settings.g.dart';

@HiveType(typeId: 2)
class Settings extends HiveObject {
  @HiveField(0)
  bool isDarkTheme = false;

  @HiveField(1)
  bool enableHaptics = true;

  @HiveField(2)
  bool saveChatHistory = true;

  @HiveField(3)
  bool autoScroll = true;

  @HiveField(4)
  bool enableVoiceInput = true;

  @HiveField(5)
  bool reduceMotion = false;

  @HiveField(6)
  bool confirmBeforeDeleting = true;

  @HiveField(7)
  int themeModeIndex = 0;

  @HiveField(8)
  bool sendWithEnter = true;

  @HiveField(9)
  bool autoFocusComposer = false;

  @HiveField(10)
  bool showStarterPrompts = true;

  // constructor
  Settings({
    required this.isDarkTheme,
    required this.enableHaptics,
    required this.saveChatHistory,
    required this.autoScroll,
    required this.enableVoiceInput,
    required this.reduceMotion,
    required this.confirmBeforeDeleting,
    required this.themeModeIndex,
    required this.sendWithEnter,
    required this.autoFocusComposer,
    required this.showStarterPrompts,
  });
}
