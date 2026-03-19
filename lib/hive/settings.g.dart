// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 2;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      isDarkTheme: fields[0] as bool? ?? false,
      enableHaptics: fields[1] as bool? ?? true,
      saveChatHistory: fields[2] as bool? ?? true,
      autoScroll: fields[3] as bool? ?? true,
      enableVoiceInput: fields[4] as bool? ?? true,
      reduceMotion: fields[5] as bool? ?? false,
      confirmBeforeDeleting: fields[6] as bool? ?? true,
      themeModeIndex:
          fields[7] as int? ?? ((fields[0] as bool? ?? false) ? 2 : 1),
      sendWithEnter: fields[8] as bool? ?? true,
      autoFocusComposer: fields[9] as bool? ?? false,
      showStarterPrompts: fields[10] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.isDarkTheme)
      ..writeByte(1)
      ..write(obj.enableHaptics)
      ..writeByte(2)
      ..write(obj.saveChatHistory)
      ..writeByte(3)
      ..write(obj.autoScroll)
      ..writeByte(4)
      ..write(obj.enableVoiceInput)
      ..writeByte(5)
      ..write(obj.reduceMotion)
      ..writeByte(6)
      ..write(obj.confirmBeforeDeleting)
      ..writeByte(7)
      ..write(obj.themeModeIndex)
      ..writeByte(8)
      ..write(obj.sendWithEnter)
      ..writeByte(9)
      ..write(obj.autoFocusComposer)
      ..writeByte(10)
      ..write(obj.showStarterPrompts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
