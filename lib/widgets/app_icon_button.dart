import 'package:flutter/material.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isEnabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: Opacity(
        opacity: isEnabled ? 1 : 0.42,
        child: IconButton(
          onPressed: isEnabled ? onTap : null,
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.62 : 0.78,
            ),
            foregroundColor: colorScheme.onPrimaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
          ),
          icon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
