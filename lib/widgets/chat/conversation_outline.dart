import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class ConversationOutline extends StatefulWidget {
  const ConversationOutline({
    super.key,
    required this.onJump,
    required this.onClose,
    this.selectedMessageId,
  });

  final ValueChanged<String> onJump;
  final VoidCallback onClose;
  final String? selectedMessageId;

  @override
  State<ConversationOutline> createState() => _ConversationOutlineState();
}

class _ConversationOutlineState extends State<ConversationOutline> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final source = context.read<ChatProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Conversation outline',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close conversation outline',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          onChanged: (value) => setState(
            () => _query = value
                .trim()
                .replaceAll(_whitespace, ' ')
                .toLowerCase(),
          ),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Find a message',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear message search',
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Selector<ChatProvider, (int, Message?)>(
            selector: (context, chat) =>
                (chat.messages.length, chat.messages.lastOrNull),
            builder: (context, _, _) {
              final messages = source.messages;
              final entries = _query.isEmpty
                  ? messages
                        .where((message) => message.role == Role.user)
                        .toList()
                  : messages
                        .where(
                          (message) => message.text
                              .replaceAll(_whitespace, ' ')
                              .toLowerCase()
                              .contains(_query),
                        )
                        .toList();
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty ? 'No prompts yet' : 'No matching messages',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 6,
                      bottom: 5,
                    ),
                    child: Text(
                      _query.isEmpty
                          ? '${entries.length} ${entries.length == 1 ? 'prompt' : 'prompts'}'
                          : '${entries.length} ${entries.length == 1 ? 'match' : 'matches'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 3),
                      itemBuilder: (context, index) {
                        final message = entries[index];
                        final selected =
                            message.messageId == widget.selectedMessageId;
                        return Material(
                          color: selected
                              ? colors.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            selected: selected,
                            selectedColor: colors.onPrimaryContainer,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            leading: Icon(
                              message.role == Role.user
                                  ? Icons.subject_rounded
                                  : Icons.auto_awesome_outlined,
                              size: 19,
                            ),
                            minLeadingWidth: 18,
                            horizontalTitleGap: 10,
                            title: Text(
                              _excerpt(message.text, _query),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              _query.isEmpty
                                  ? 'Prompt ${index + 1}'
                                  : (message.role == Role.user
                                        ? 'You'
                                        : 'Gemini'),
                              style: theme.textTheme.labelSmall,
                            ),
                            onTap: () => widget.onJump(message.messageId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static final _whitespace = RegExp(r'\s+');

  String _excerpt(String message, String query) {
    final text = message.replaceAll(_whitespace, ' ').trim();
    final match = query.isEmpty ? 0 : text.toLowerCase().indexOf(query);
    final start = (match - 26).clamp(0, text.length);
    final end = (start + 130).clamp(start, text.length);
    return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
  }
}
