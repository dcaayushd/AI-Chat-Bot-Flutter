import 'package:flutter/material.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topColor = Color.lerp(
      colorScheme.surface,
      colorScheme.secondaryContainer,
      colorScheme.brightness == Brightness.dark ? 0.18 : 0.16,
    )!;
    final middleColor = Color.lerp(
      colorScheme.surface,
      colorScheme.primaryContainer,
      colorScheme.brightness == Brightness.dark ? 0.08 : 0.08,
    )!;
    final bottomColor = Color.lerp(
      colorScheme.surface,
      colorScheme.tertiaryContainer,
      colorScheme.brightness == Brightness.dark ? 0.16 : 0.14,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            topColor,
            middleColor,
            bottomColor,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            left: -60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.secondary.withValues(
                      alpha: colorScheme.brightness == Brightness.dark
                          ? 0.14
                          : 0.08,
                    ),
                    blurRadius: 180,
                    spreadRadius: 88,
                  ),
                ],
              ),
              child: const SizedBox.square(dimension: 200),
            ),
          ),
          Positioned(
            right: -90,
            top: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: colorScheme.brightness == Brightness.dark
                          ? 0.12
                          : 0.08,
                    ),
                    blurRadius: 170,
                    spreadRadius: 84,
                  ),
                ],
              ),
              child: const SizedBox.square(dimension: 180),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.tertiary.withValues(
                      alpha: colorScheme.brightness == Brightness.dark
                          ? 0.14
                          : 0.08,
                    ),
                    blurRadius: 180,
                    spreadRadius: 88,
                  ),
                ],
              ),
              child: const SizedBox.square(dimension: 190),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -70,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: colorScheme.brightness == Brightness.dark
                          ? 0.08
                          : 0.05,
                    ),
                    blurRadius: 140,
                    spreadRadius: 72,
                  ),
                ],
              ),
              child: const SizedBox.square(dimension: 130),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
