import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:provider/provider.dart';

class EmptyHistoryWidget extends StatelessWidget {
  const EmptyHistoryWidget({
    super.key,
    this.isFiltered = false,
  });

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Card(
        child: InkWell(
          onTap: () async {
            final chatProvider = context.read<ChatProvider>();
            await chatProvider.prepareChatRoom(
              isNewChat: true,
              chatID: '',
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFiltered
                      ? CupertinoIcons.search
                      : CupertinoIcons.chat_bubble_2,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  isFiltered ? 'No matches' : 'No chats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    final chatProvider = context.read<ChatProvider>();
                    await chatProvider.prepareChatRoom(
                      isNewChat: true,
                      chatID: '',
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('New chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
