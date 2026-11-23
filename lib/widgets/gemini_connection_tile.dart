import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class GeminiConnectionTile extends StatelessWidget {
  const GeminiConnectionTile({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = context.select<ChatProvider, (bool, bool, String)>(
      (chat) => (chat.isConfigured, chat.hasSessionKey, chat.model),
    );
    final (configured, sessionKey, model) = connection;
    final status = sessionKey
        ? 'Session key set'
        : (configured ? 'Development key set' : 'API key required');

    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: const Icon(Icons.key_outlined),
        title: const Text('Gemini connection'),
        subtitle: Text('$status\n$model'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _editKey(context, sessionKey),
      ),
    );
  }

  Future<void> _editKey(BuildContext context, bool hasSessionKey) async {
    final chat = context.read<ChatProvider>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _ApiKeyDialog(hasSessionKey: hasSessionKey),
    );
    if (value == null || !context.mounted) return;
    try {
      chat.setSessionKey(value);
      final status = value.isEmpty ? 'Session key removed' : 'Session key set';
      showAppSnackBar(context, status);
    } catch (error) {
      showAppSnackBar(context, formatChatError(error));
    }
  }
}

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.hasSessionKey});

  final bool hasSessionKey;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final key = _controller.text.trim();
    if (key.isNotEmpty) Navigator.of(context).pop(key);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Gemini API key'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paste a key from Google AI Studio. You can use it until you close the app.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'API key'),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.hasSessionKey)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Remove key'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _save,
            child: const Text('Use key'),
          ),
        ),
      ],
    );
  }
}
