import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chatbotapp/utilities/assets_manager.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.imagePath,
    this.radius = 24,
  });

  final String name;
  final String imagePath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageProvider = _imageProvider();
    final initials = _initials();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? Text(
                initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              )
            : null,
      ),
    );
  }

  ImageProvider<Object>? _imageProvider() {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isNotEmpty) {
      final imageFile = File(normalizedPath);
      if (imageFile.existsSync()) {
        return FileImage(imageFile);
      }
    }

    if (name.trim().isEmpty) {
      return const AssetImage(AssetsMenager.userIcon);
    }

    return null;
  }

  String _initials() {
    final parts =
        name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'Y';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
