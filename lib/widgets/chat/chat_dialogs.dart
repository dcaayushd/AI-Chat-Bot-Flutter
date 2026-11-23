import 'package:chatbotapp/models/chat_options.dart';
import 'package:material_ui/material_ui.dart';

class ChatOptionsDialog extends StatefulWidget {
  const ChatOptionsDialog({super.key, required this.options});

  final ChatOptions options;

  @override
  State<ChatOptionsDialog> createState() => _ChatOptionsDialogState();
}

class _ChatOptionsDialogState extends State<ChatOptionsDialog> {
  late final _instructions = TextEditingController(
    text: widget.options.instructions,
  );
  late ReplyLength _length = widget.options.length;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Chat options'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ReplyLength>(
              initialValue: _length,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reply length'),
              items: [
                for (final length in ReplyLength.values)
                  DropdownMenuItem(
                    value: length,
                    child: Text(
                      length.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (length) =>
                  setState(() => _length = length ?? _length),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _instructions,
              minLines: 3,
              maxLines: 6,
              maxLength: ChatOptions.maxInstructionsLength,
              decoration: const InputDecoration(
                labelText: 'Instructions for this chat',
                hintText: 'Use practical examples and explain tradeoffs',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ChatOptions(length: _length, instructions: _instructions.text)),
          child: const Text('Save options'),
        ),
      ],
    );
  }
}

class PromptEditorDialog extends StatefulWidget {
  const PromptEditorDialog({
    super.key,
    required this.text,
    required this.maxLength,
  });

  final String text;
  final int maxLength;

  @override
  State<PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<PromptEditorDialog> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Edit in a branch'),
      content: SizedBox(
        width: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The new chat includes the messages and attachments through this prompt.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              maxLength: widget.maxLength,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (context, draft, _) => FilledButton(
            onPressed: draft.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(draft.text),
            child: const Text('Send in branch'),
          ),
        ),
      ],
    );
  }
}
