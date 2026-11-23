import 'dart:io';

import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/settings.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/testing.dart';

void main() {
  late Directory storage;

  setUpAll(() {
    Hive.registerAdapter(SettingsAdapter());
    Hive.registerAdapter(UserModelAdapter());
  });

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('chatbot-preferences-');
    Hive.init(storage.path);
    await Hive.openBox<Settings>(Constants.settingsBox);
    await Hive.openBox<UserModel>(Constants.userBox);
  });

  tearDown(() async {
    await Hive.close();
    await storage.delete(recursive: true);
  });

  test(
    'keeps settings from overlapping writes and reloads them from disk',
    () async {
      await Boxes.getSettings().put(
        'older-key',
        Settings(confirmBeforeDeleting: false),
      );
      final provider = SettingsProvider()..getSavedSettings();
      addTearDown(provider.dispose);

      await Future.wait([
        provider.toggleSaveChatHistory(value: false),
        provider.setThemeMode(value: AppThemeMode.dark),
        provider.toggleVoiceInput(value: false),
      ]);

      await Boxes.getSettings().close();
      final box = await Hive.openBox<Settings>(Constants.settingsBox);
      final reloaded = SettingsProvider()..getSavedSettings();
      addTearDown(reloaded.dispose);
      expect(reloaded.saveChatHistory, isFalse);
      expect(reloaded.appThemeMode, AppThemeMode.dark);
      expect(reloaded.enableVoiceInput, isFalse);
      expect(box.keys, ['older-key']);
      expect(box.values.single.confirmBeforeDeleting, isFalse);
    },
  );

  test(
    'a failed settings write leaves the preference usable and retryable',
    () async {
      final provider = SettingsProvider()..getSavedSettings();
      addTearDown(provider.dispose);
      await Boxes.getSettings().close();

      await expectLater(
        provider.toggleSaveChatHistory(value: false),
        throwsA(isA<HiveError>()),
      );
      expect(provider.saveChatHistory, isTrue);

      await Hive.openBox<Settings>(Constants.settingsBox);
      await provider.toggleSaveChatHistory(value: false);
      expect(provider.saveChatHistory, isFalse);
      expect(Boxes.getSettings().values.single.saveChatHistory, isFalse);
    },
  );

  test(
    'migrates an existing avatar off its temporary path when saving a profile',
    () async {
      final photo = MockClient.pngResponse().bodyBytes;
      final temporaryPhoto = File.fromUri(
        storage.uri.resolve('old-avatar.png'),
      );
      await temporaryPhoto.writeAsBytes(photo);
      await Boxes.getUser().add(
        UserModel(
          uid: 'existing-user',
          name: 'Old name',
          image: temporaryPhoto.path,
        ),
      );

      final profile = UserProfileProvider();
      addTearDown(profile.dispose);
      await profile.loadUser();
      expect(profile.avatarBytes, photo);
      await profile.saveProfile(name: 'New name');
      await temporaryPhoto.delete();
      await Boxes.getUser().close();
      final box = await Hive.openBox<UserModel>(Constants.userBox);

      final reloaded = UserProfileProvider();
      addTearDown(reloaded.dispose);
      await reloaded.loadUser();
      expect(reloaded.name, 'New name');
      expect(reloaded.avatarBytes, photo);
      expect(box.values.single.uid, 'existing-user');
      expect(box.values.single.image, isEmpty);
    },
  );
}
