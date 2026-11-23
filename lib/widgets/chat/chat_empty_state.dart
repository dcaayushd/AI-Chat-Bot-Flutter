import 'dart:math' as math;

import 'package:chatbotapp/models/chat_mode.dart';
import 'package:material_ui/material_ui.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.mode,
    required this.apiConfigured,
    required this.showStarterPrompts,
    required this.onSuggestionTap,
    required this.onConnect,
  });

  final ChatMode mode;
  final bool apiConfigured;
  final bool showStarterPrompts;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onConnect;

  static const _maxWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, _maxWidth);
        final textScale = MediaQuery.textScalerOf(context).scale(14);
        final tileWidth = width >= 304 && textScale < 23
            ? (width - 12) / 2
            : width;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.onPrimaryContainer,
                            size: 27,
                          ),
                        ),
                      ),
                      const SizedBox(height: 19),
                      Semantics(
                        header: true,
                        child: Text(
                          'How can I help?',
                          style: width >= 480
                              ? theme.textTheme.headlineLarge
                              : theme.textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mode.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (showStarterPrompts) ...[
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final prompt in mode.prompts)
                              SizedBox(
                                width: tileWidth,
                                child: _PromptTile(
                                  prompt: prompt,
                                  onTap: () => onSuggestionTap(prompt),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (!apiConfigured) ...[
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          onPressed: onConnect,
                          icon: const Icon(Icons.key_outlined, size: 18),
                          label: const Text('Connect Gemini'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({required this.prompt, required this.onTap});

  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(prompt, style: theme.textTheme.labelLarge),
                ),
                const SizedBox(width: 8),
                Icon(Icons.north_west_rounded, color: colors.primary, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
