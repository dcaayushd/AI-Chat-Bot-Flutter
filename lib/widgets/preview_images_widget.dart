import 'package:flutter/cupertino.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:provider/provider.dart';

class PreviewImagesWidget extends StatelessWidget {
  const PreviewImagesWidget({
    super.key,
    this.message,
    this.canRemove = false,
    this.onRemoveAt,
    this.imageSize = 84,
  });

  final Message? message;
  final bool canRemove;
  final ValueChanged<int>? onRemoveAt;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final messageToShow =
            message != null ? message!.imagesUrls : chatProvider.imagesFileList;
        if (messageToShow == null || messageToShow.isEmpty) {
          return const SizedBox.shrink();
        }

        final padding = message != null
            ? EdgeInsets.zero
            : const EdgeInsets.only(left: 4, right: 4, bottom: 4);

        return Padding(
          padding: padding,
          child: SizedBox(
            height: imageSize + 16,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: messageToShow.length,
              itemBuilder: (context, index) {
                final imagePath = message != null
                    ? message!.imagesUrls[index]
                    : chatProvider.imagesFileList![index].path;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(
                          File(imagePath),
                          height: imageSize,
                          width: imageSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (canRemove && onRemoveAt != null)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Material(
                            color: Theme.of(context).colorScheme.error,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => onRemoveAt!(index),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
