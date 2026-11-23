import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/widgets/chat/assistant_response_content.dart';
import 'package:material_ui/material_ui.dart';

class ReplyVersionsDialog extends StatefulWidget {
  const ReplyVersionsDialog({
    super.key,
    required this.message,
    required this.canRestore,
  });

  final Message message;
  final bool canRestore;

  @override
  State<ReplyVersionsDialog> createState() => _ReplyVersionsDialogState();
}

class _ReplyVersionsDialogState extends State<ReplyVersionsDialog> {
  late final _versions = [
    widget.message.revision,
    ...widget.message.previousReplies,
  ];
  late int _selected = widget.message.previousReplies.isEmpty ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final version = _versions[_selected];
    final status = switch (version.status) {
      ReplyStatus.complete => 'Complete',
      ReplyStatus.stopped => 'Stopped',
      ReplyStatus.interrupted => 'Interrupted',
      ReplyStatus.truncated => 'Reached length limit',
    };
    return AlertDialog(
      scrollable: true,
      title: const Text('Reply versions'),
      content: SizedBox(
        width: 610,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Version'),
              items: [
                for (final (index, _) in _versions.indexed)
                  DropdownMenuItem(
                    value: index,
                    child: Text(
                      index == 0 ? 'Current reply' : 'Earlier reply $index',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (index) =>
                  setState(() => _selected = index ?? _selected),
            ),
            const SizedBox(height: 12),
            Text(
              '${localizations.formatShortDate(version.timeSent.toLocal())} · '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(version.timeSent.toLocal()))} · $status',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 14),
            AssistantResponseContent(
              key: ValueKey(_selected),
              text: version.text,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (widget.canRestore)
          FilledButton(
            onPressed: _selected == 0
                ? null
                : () => Navigator.of(context).pop(version),
            child: const Text('Use this version'),
          ),
      ],
    );
  }
}
