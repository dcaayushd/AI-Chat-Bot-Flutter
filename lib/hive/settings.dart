import 'package:hive_flutter/hive_flutter.dart';

part 'settings.g.dart';

@HiveType(typeId: 2)
class Settings extends HiveObject {
  @HiveField(0)
  bool isDarkTheme;

  @HiveField(1)
  bool enableHaptics;

  @HiveField(2)
  bool saveChatHistory;

  @HiveField(3)
  bool autoScroll;

  @HiveField(4)
  bool enableVoiceInput;

  @HiveField(5)
  bool reduceMotion;

  @HiveField(6)
  bool confirmBeforeDeleting;

  @HiveField(7)
  int themeModeIndex;

  @HiveField(8)
  bool sendWithEnter;

  @HiveField(9)
  bool autoFocusComposer;

  @HiveField(10)
  bool showStarterPrompts;

  Settings({
    this.isDarkTheme = false,
    this.enableHaptics = true,
    this.saveChatHistory = true,
    this.autoScroll = true,
    this.enableVoiceInput = true,
    this.reduceMotion = false,
    this.confirmBeforeDeleting = true,
    this.themeModeIndex = 0,
    this.sendWithEnter = true,
    this.autoFocusComposer = false,
    this.showStarterPrompts = true,
  });

  Settings copy() => Settings(
    isDarkTheme: isDarkTheme,
    enableHaptics: enableHaptics,
    saveChatHistory: saveChatHistory,
    autoScroll: autoScroll,
    enableVoiceInput: enableVoiceInput,
    reduceMotion: reduceMotion,
    confirmBeforeDeleting: confirmBeforeDeleting,
    themeModeIndex: themeModeIndex,
    sendWithEnter: sendWithEnter,
    autoFocusComposer: autoFocusComposer,
    showStarterPrompts: showStarterPrompts,
  );
}
