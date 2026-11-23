import 'package:material_ui/material_ui.dart';

class EmptyHistoryWidget extends StatelessWidget {
  const EmptyHistoryWidget({
    super.key,
    required this.isFiltered,
    this.onAction,
  });

  final bool isFiltered;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered
                ? Icons.search_rounded
                : Icons.chat_bubble_outline_rounded,
            size: 30,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'No matches' : 'No saved chats',
            style: theme.textTheme.titleMedium,
          ),
          if (onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(isFiltered ? 'Clear search' : 'New chat'),
            ),
          ],
        ],
      ),
    );
  }
}
