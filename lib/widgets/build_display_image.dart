import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chatbotapp/utilities/assets_manager.dart';

class BuildDisplayImage extends StatelessWidget {
  const BuildDisplayImage({
    super.key,
    required this.file,
    required this.userImage,
    required this.onPressed,
    this.radius = 44,
  });

  final File? file;
  final String userImage;
  final VoidCallback onPressed;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
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
            backgroundImage: getImageToShow(),
          ),
        ),
        Positioned(
          bottom: -4,
          right: -4,
          child: InkWell(
            onTap: onPressed,
            child: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              radius: 18,
              child: Icon(
                CupertinoIcons.camera_fill,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider<Object> getImageToShow() {
    if (file != null) {
      return FileImage(File(file!.path));
    }

    final normalizedPath = userImage.trim();
    if (normalizedPath.isNotEmpty) {
      final savedFile = File(normalizedPath);
      if (savedFile.existsSync()) {
        return FileImage(savedFile);
      }
    }

    return const AssetImage(AssetsMenager.userIcon);
  }
}
