import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photo,
    this.onPickPhoto,
    this.radius = 24,
  });

  final String name;
  final Uint8List? photo;
  final VoidCallback? onPickPhoto;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bytes = photo;
    final placeholder = Center(
      child: Text(_initials(), style: theme.textTheme.titleMedium),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.primary, colors.secondary],
            ),
          ),
          child: ClipOval(
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child: SizedBox.square(
                dimension: radius * 2,
                child: bytes == null
                    ? placeholder
                    : Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        cacheWidth: (radius * 6).round(),
                        semanticLabel: 'Profile photo',
                        errorBuilder: (_, __, ___) => placeholder,
                      ),
              ),
            ),
          ),
        ),
        if (onPickPhoto != null)
          Positioned(
            bottom: -4,
            right: -4,
            child: IconButton.filledTonal(
              tooltip: 'Choose profile photo',
              onPressed: onPickPhoto,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
            ),
          ),
      ],
    );
  }

  String _initials() {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    if (words.isEmpty) return 'Y';
    final first = String.fromCharCode(words.first.runes.first);
    if (words.length == 1) return first.toUpperCase();
    final last = String.fromCharCode(words.last.runes.first);
    return (first + last).toUpperCase();
  }
}
