import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.userName,
    required this.modelLabel,
    required this.canStartNewChat,
    required this.onOpenHistory,
    required this.onOpenSettings,
    required this.onNewChat,
  });

  final String userName;
  final String modelLabel;
  final bool canStartNewChat;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CompactMetric(
                        icon: CupertinoIcons.sparkles,
                        label: modelLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: CupertinoIcons.square_pencil,
              tooltip: 'New chat',
              isEnabled: canStartNewChat,
              onTap: onNewChat,
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: CupertinoIcons.clock,
              tooltip: 'History',
              onTap: onOpenHistory,
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: CupertinoIcons.settings,
              tooltip: 'Settings',
              onTap: onOpenSettings,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
