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

  static const _maxWidth = 540.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.min(constraints.maxWidth, _maxWidth) - 8;
        final textScale = MediaQuery.textScalerOf(context).scale(14);
        final tileWidth = availableWidth >= 300 && textScale < 23
            ? (availableWidth - 10) / 2
            : availableWidth;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primaryContainer,
                              colors.secondaryContainer
                            ],
                          ),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(17),
                          child: Icon(Icons.auto_awesome_rounded,
                              color: colors.onPrimaryContainer, size: 30),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'How can I help?',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mode.description,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: colors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      if (showStarterPrompts) ...[
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final prompt in mode.prompts)
                              SizedBox(
                                width: tileWidth,
                                child: _PromptTile(
                                    prompt: prompt,
                                    onTap: () => onSuggestionTap(prompt)),
                              ),
                          ],
                        ),
                      ],
                      if (!apiConfigured) ...[
                        const SizedBox(height: 18),
                        TextButton.icon(
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
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Expanded(child: Text(prompt, style: theme.textTheme.labelLarge)),
              const SizedBox(width: 4),
              Icon(Icons.north_west_rounded, color: colors.primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
