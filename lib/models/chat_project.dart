import 'package:chatbotapp/utilities/chat_error_formatter.dart';

class ChatProject {
  const ChatProject._({
    required this.id,
    required this.name,
    required this.instructions,
    required this.referenceNotes,
  });

  static const maxNameLength = 64;
  static const maxInstructionsLength = 2000;
  static const maxReferenceLength = 12000;

  final String id;
  final String name;
  final String instructions;
  final String referenceNotes;

  factory ChatProject({
    required String id,
    required String name,
    String instructions = '',
    String referenceNotes = '',
  }) {
    final title = name.trim();
    final prompt = instructions.trim();
    final notes = referenceNotes.trim();
    if (title.isEmpty || title.length > maxNameLength) {
      throw const ChatException(
        'Use a project name between 1 and 64 characters.',
      );
    }
    if (prompt.length > maxInstructionsLength) {
      throw const ChatException(
        'Keep project instructions within 2,000 characters.',
      );
    }
    if (notes.length > maxReferenceLength) {
      throw const ChatException(
        'Keep project reference notes within 12,000 characters.',
      );
    }
    return ChatProject._(
      id: id,
      name: title,
      instructions: prompt,
      referenceNotes: notes,
    );
  }

  static ChatProject? tryFromMap(String id, Map? value) {
    if (value case {
      'name': final String name,
      'instructions': final String instructions,
      'referenceNotes': final String notes,
    }) {
      try {
        return ChatProject(
          id: id,
          name: name,
          instructions: instructions,
          referenceNotes: notes,
        );
      } on ChatException {
        return null;
      }
    }
    return null;
  }

  Map<String, String> toMap() => {
    'name': name,
    'instructions': instructions,
    'referenceNotes': referenceNotes,
  };
}
