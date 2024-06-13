import 'package:flutter/material.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/settings.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _shouldSpeak = false;

  bool get isDarkMode => _isDarkMode;

  bool get shouldSpeak => _shouldSpeak;

  // get the saved settings from box
  void getSavedSettings() {
    final settingsBox = Boxes.getSettings();

    // check is the settings box is open
    if (settingsBox.isNotEmpty) {
      // get the settings
      final settings = settingsBox.getAt(0);
      _isDarkMode = settings!.isDarkTheme;
      _shouldSpeak = settings.shouldSpeak;
    }
  }

  // toggle the dark mode
  void toggleDarkMode({
    required bool value,
    Settings? settings,
  }) {
    if (settings != null) {
      settings.isDarkTheme = value;
      settings.save();
    } else {
      // get the settings box
      final settingsBox = Boxes.getSettings();
      // save the settings
      settingsBox.put(
          0, Settings(isDarkTheme: value, shouldSpeak: shouldSpeak));
    }

    _isDarkMode = value;
    notifyListeners();
  }

  // toggle the speak
  void toggleSpeak({
    required bool value,
    Settings? settings,
  }) {
    if (settings != null) {
      settings.shouldSpeak = value;
      settings.save();
    } else {
      // get the settings box
      final settingsBox = Boxes.getSettings();
      // save the settings
      settingsBox.put(0, Settings(isDarkTheme: isDarkMode, shouldSpeak: value));
    }

    _shouldSpeak = value;
    notifyListeners();
  }
}
