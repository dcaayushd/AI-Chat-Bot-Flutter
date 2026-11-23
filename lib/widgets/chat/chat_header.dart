import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';
import 'package:material_ui/material_ui.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.userName,
    required this.mode,
    required this.historyOff,
    required this.isBusy,
    required this.onModeChanged,
    required this.onOptions,
    this.onOpenHistory,
    this.onOpenSettings,
    this.onNewChat,
    this.onCopyChat,
  });

  final String title;
  final String userName;
  final ChatMode mode;
  final bool historyOff;
  final bool isBusy;
  final ValueChanged<ChatMode> onModeChanged;
  final VoidCallback onOptions;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onNewChat;
  final VoidCallback? onCopyChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final heading = Expanded(
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    final modePicker = _ModePicker(
      mode: mode,
      enabled: !isBusy,
      onChanged: onModeChanged,
    );
    final historyStatus = Text(
      'History off',
      textAlign: TextAlign.end,
      style: theme.textTheme.labelMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
    final copyAction = IconButton(
      tooltip: 'Copy conversation',
      onPressed: onCopyChat,
      icon: const Icon(Icons.copy_all_outlined, size: 20),
    );
    final optionsAction = IconButton(
      tooltip: 'Chat options',
      onPressed: isBusy ? null : onOptions,
      icon: const Icon(Icons.tune_rounded, size: 20),
    );

    if (onOpenHistory == null) {
      return Row(
        children: [
          heading,
          if (historyOff) ...[const SizedBox(width: 12), historyStatus],
          const SizedBox(width: 12),
          modePicker,
          optionsAction,
          if (onCopyChat != null) copyAction,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            heading,
            if (onCopyChat != null) copyAction,
            IconButton(
              tooltip: 'History',
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history_rounded, size: 23),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 22),
            ),
            const SizedBox(width: 4),
            if (onNewChat case final newChat?)
              AppIconButton(
                icon: Icons.edit_square,
                tooltip: 'New chat',
                onTap: newChat,
              ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            modePicker,
            optionsAction,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (historyOff) ...[
              const Spacer(),
              const SizedBox(width: 8),
              Flexible(flex: 2, child: historyStatus),
            ],
          ],
        ),
      ],
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final ChatMode mode;
  final bool enabled;
  final ValueChanged<ChatMode> onChanged;

  static IconData _icon(ChatMode mode) => switch (mode) {
    ChatMode.general => Icons.auto_awesome_outlined,
    ChatMode.writing => Icons.edit_note_rounded,
    ChatMode.coding => Icons.code_rounded,
    ChatMode.study => Icons.school_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MenuAnchor(
      menuChildren: [
        for (final option in ChatMode.values)
          MenuItemButton(
            leadingIcon: Icon(_icon(option)),
            trailingIcon: option == mode
                ? const Icon(Icons.check_rounded, size: 18)
                : null,
            onPressed: () => onChanged(option),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label),
                Text(
                  option.description,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: colors.surfaceContainerLow,
          minimumSize: const Size(0, 40),
        ),
        icon: Icon(_icon(mode), size: 17),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode.label),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}
