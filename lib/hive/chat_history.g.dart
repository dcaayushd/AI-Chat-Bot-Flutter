// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatHistoryAdapter extends TypeAdapter<ChatHistory> {
  @override
  final int typeId = 0;

  @override
  ChatHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatHistory(
      chatId: fields[0] as String,
      prompt: fields[1] as String,
      response: fields[2] as String,
      imagesUrls: (fields[3] as List).cast<String>(),
      timestamp: fields[4] as DateTime,
      title: fields[5] as String?,
      isPinned: fields[6] == null ? false : fields[6] as bool,
      transcript: (fields[7] as List?)?.whereType<Map>().toList(),
      mode: fields[8] as String?,
      options: fields[9] is Map ? fields[9] as Map : null,
      projectId: fields[10] is String ? fields[10] as String : null,
    );
  }

  @override
  void write(BinaryWriter writer, ChatHistory obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.chatId)
      ..writeByte(1)
      ..write(obj.prompt)
      ..writeByte(2)
      ..write(obj.response)
      ..writeByte(3)
      ..write(obj.imagesUrls)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.transcript)
      ..writeByte(8)
      ..write(obj.mode)
      ..writeByte(9)
      ..write(obj.options)
      ..writeByte(10)
      ..write(obj.projectId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
