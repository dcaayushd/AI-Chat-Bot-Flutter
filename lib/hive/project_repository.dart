import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/models/chat_project.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:hive/hive.dart';

class ProjectRepository {
  Box<Map>? get _box => Hive.isBoxOpen(Constants.chatProjectsBox)
      ? Hive.box<Map>(Constants.chatProjectsBox)
      : null;

  Box<Map> get _storage =>
      _box ?? (throw const ChatException('Project storage is unavailable.'));

  ChatProject? get(String? id) =>
      id == null ? null : ChatProject.tryFromMap(id, _box?.get(id));

  List<ChatProject> list() {
    final box = _box;
    if (box == null) return const [];
    final projects = box.keys
        .whereType<String>()
        .map((id) => ChatProject.tryFromMap(id, box.get(id)))
        .nonNulls
        .toList();
    return projects
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> save(ChatProject project) =>
      _storage.put(project.id, project.toMap());

  Future<void> delete(String id) => _storage.delete(id);
}
