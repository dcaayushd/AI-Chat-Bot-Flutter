import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:material_ui/material_ui.dart';

enum AppThemeMode { auto, light, dark }

class SettingsProvider extends ChangeNotifier {
  Settings _settings = Settings();
  Future<void> _writes = Future.value();
  bool _disposed = false;

  AppThemeMode get appThemeMode {
    final index = _settings.themeModeIndex;
    if (index >= 0 && index < AppThemeMode.values.length) {
      return AppThemeMode.values[index];
    }
    return _settings.isDarkTheme ? AppThemeMode.dark : AppThemeMode.light;
  }

  ThemeMode get themeMode => switch (appThemeMode) {
    AppThemeMode.auto => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  bool get enableHaptics => _settings.enableHaptics;
  bool get saveChatHistory => _settings.saveChatHistory;
  bool get autoScroll => _settings.autoScroll;
  bool get enableVoiceInput => _settings.enableVoiceInput;
  bool get reduceMotion => _settings.reduceMotion;
  bool get sendWithEnter => _settings.sendWithEnter;
  bool get autoFocusComposer => _settings.autoFocusComposer;
  bool get showStarterPrompts => _settings.showStarterPrompts;

  void getSavedSettings() {
    _settings = Boxes.getSettings().values.firstOrNull ?? Settings();
  }

  Future<void> setThemeMode({required AppThemeMode value}) =>
      _update((settings) {
        settings.isDarkTheme = value == AppThemeMode.dark;
        settings.themeModeIndex = value.index;
      });

  Future<void> toggleHaptics({required bool value}) =>
      _update((settings) => settings.enableHaptics = value);

  Future<void> toggleSaveChatHistory({required bool value}) =>
      _update((settings) => settings.saveChatHistory = value);

  Future<void> toggleAutoScroll({required bool value}) =>
      _update((settings) => settings.autoScroll = value);

  Future<void> toggleVoiceInput({required bool value}) =>
      _update((settings) => settings.enableVoiceInput = value);

  Future<void> toggleReduceMotion({required bool value}) =>
      _update((settings) => settings.reduceMotion = value);

  Future<void> toggleSendWithEnter({required bool value}) =>
      _update((settings) => settings.sendWithEnter = value);

  Future<void> toggleAutoFocusComposer({required bool value}) =>
      _update((settings) => settings.autoFocusComposer = value);

  Future<void> toggleShowStarterPrompts({required bool value}) =>
      _update((settings) => settings.showStarterPrompts = value);

  Future<void> _update(void Function(Settings) change) {
    final write = _writes.then((_) async {
      final updated = _settings.copy();
      change(updated);
      final box = Boxes.getSettings();
      await box.put(box.keys.firstOrNull ?? 0, updated);
      _settings = updated;
      if (!_disposed) notifyListeners();
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
