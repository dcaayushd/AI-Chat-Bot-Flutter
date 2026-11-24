import 'package:chatbotapp/models/chat_project.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ProjectPicker extends StatelessWidget {
  const ProjectPicker({
    super.key,
    required this.projects,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ChatProject> projects;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  Future<void> _edit(BuildContext context, ChatProject? project) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ProjectEditor(project: project),
    );
    if (result != null && context.mounted) {
      onChanged(result.isEmpty ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = projects
        .where((project) => project.id == selectedId)
        .firstOrNull;
    final editingEnabled = !context.select((ChatProvider chat) => chat.isBusy);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.all_inbox_outlined, size: 19),
          onPressed: () => onChanged(null),
          child: const Text('All chats'),
        ),
        for (final project in projects)
          MenuItemButton(
            leadingIcon: const Icon(Icons.folder_outlined, size: 19),
            trailingIcon: project.id == selectedId
                ? const Icon(Icons.check_rounded, size: 17)
                : null,
            onPressed: () => onChanged(project.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        const Divider(height: 10),
        MenuItemButton(
          leadingIcon: const Icon(Icons.create_new_folder_outlined, size: 20),
          onPressed: editingEnabled ? () => _edit(context, null) : null,
          child: const Text('New project'),
        ),
        if (selected != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: editingEnabled ? () => _edit(context, selected) : null,
            child: const Text('Edit project'),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.name ?? (projects.isEmpty ? 'Projects' : 'All chats'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<String?> showProjectAssignment(
  BuildContext context, {
  required List<ChatProject> projects,
  required String? currentId,
}) => showDialog<String>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Move to project'),
    children: [
      SimpleDialogOption(
        onPressed: () => Navigator.of(context).pop(''),
        child: const Text('No project'),
      ),
      for (final project in projects)
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(project.id),
          child: Row(
            children: [
              Expanded(child: Text(project.name)),
              if (project.id == currentId)
                const Icon(Icons.check_rounded, size: 19),
            ],
          ),
        ),
    ],
  ),
);

class _ProjectEditor extends StatefulWidget {
  const _ProjectEditor({this.project});

  final ChatProject? project;

  @override
  State<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<_ProjectEditor> {
  late final _name = TextEditingController(text: widget.project?.name);
  late final _instructions = TextEditingController(
    text: widget.project?.instructions,
  );
  late final _notes = TextEditingController(
    text: widget.project?.referenceNotes,
  );
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _commit(Future<String> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final id = await action();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(id);
      }
    } catch (error) {
      if (mounted) setState(() => _error = formatChatError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() => _commit(() async {
    final project = await context.read<ChatProvider>().saveProject(
      id: widget.project?.id,
      name: _name.text,
      instructions: _instructions.text,
      referenceNotes: _notes.text,
    );
    return project.id;
  });

  Future<void> _remove(ChatProject project) async {
    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Remove project?',
      content: 'Its chats stay in All chats. Its instructions, reference notes, and new-chat draft will be deleted.',
      actionText: 'Remove project',
    );
    if (!confirmed || !mounted) return;
    await _commit(() async {
      await context.read<ChatProvider>().removeProject(project.id);
      return '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.project == null ? 'New project' : 'Edit project'),
      content: SizedBox(
        width: 500,
        child: Focus(
          canRequestFocus: false,
          descendantsAreFocusable: !_working,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.project == null,
                maxLength: ChatProject.maxNameLength,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructions,
                maxLength: ChatProject.maxInstructionsLength,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Project instructions',
                  hintText: 'Use checklist format for release plans',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLength: ChatProject.maxReferenceLength,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Reference notes',
                  hintText:
                      'Add milestones, decisions, or background information',
                  alignLabelWithHint: true,
                ),
              ),
              Text(
                'Gemini receives these instructions and notes when you send a message in this project.',
                style: theme.textTheme.bodySmall,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.project case final project?)
          TextButton(
            onPressed: _working ? null : () => _remove(project),
            child: const Text('Remove project'),
          ),
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, _) => FilledButton(
            onPressed: _working || value.text.trim().isEmpty ? null : _save,
            child: Text(_working ? 'Working…' : 'Save project'),
          ),
        ),
      ],
    );
  }
}
