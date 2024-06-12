import 'dart:developer';

import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utility/utilities.dart';
import 'package:chatbotapp/widgets/preview_images_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BottomChatField extends StatefulWidget {
  const BottomChatField({
    super.key,
    required this.chatProvider,
  });

  final ChatProvider chatProvider;

  @override
  State<BottomChatField> createState() => _BottomChatFieldState();
}

class _BottomChatFieldState extends State<BottomChatField> {
  // Controller for the Input Field
  final TextEditingController textController = TextEditingController();

  // Focus Node for the input field
  final FocusNode textFieldFocus = FocusNode();

  // Initialize image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    textController.dispose();
    textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> sendChatMessage({
    required String message,
    required ChatProvider chatProvider,
    required bool isTextOnly,
  }) async {
    try {
      await chatProvider.sentMessage(
        message: message,
        isTextOnly: isTextOnly,
      );
    } catch (e) {
      log('error : $e');
    } finally {
      textController.clear();
      widget.chatProvider.setImagesFileList(listValue: []);
      textFieldFocus.unfocus();
    }
  }

  // Pick an image
  void pickImage() async {
    try {
      final pickedImages = await _picker.pickMultiImage(
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 95,
      );
      widget.chatProvider.setImagesFileList(listValue: pickedImages);
    } catch (e) {
      log('error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasImages = widget.chatProvider.imagesFileList != null &&
        widget.chatProvider.imagesFileList!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Theme.of(context).textTheme.titleLarge!.color!,
          )
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.grey.withOpacity(0.5),
          //     spreadRadius: 5,
          //     blurRadius: 7,
          //     offset: const Offset(0, 3),
          //   ),
          // ],
          ),
      child: Column(
        children: [
          if (hasImages) const PreviewImagesWidget(),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  // ! Pick an Image
                  if (hasImages) {
                    // Show the delete dialog
                    showMyAnimatedDialog(
                      context: context,
                      title: 'Delete Images',
                      content: 'Are you sure you want to delete the images?',
                      actionText: 'Delete',
                      onActionPressed: (value) {
                        if (value) {
                          widget.chatProvider.setImagesFileList(listValue: []);
                        }
                      },
                    );
                  } else {
                    pickImage();
                  }
                },
                icon: Icon(
                    hasImages ? CupertinoIcons.delete : CupertinoIcons.photo),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  focusNode: textFieldFocus,
                  controller: textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (String value) {
                    if (value.isNotEmpty) {
                      // Send the Message
                      sendChatMessage(
                        message: textController.text,
                        chatProvider: widget.chatProvider,
                        isTextOnly: hasImages ? false : true,
                      );
                    }
                  },
                  decoration: InputDecoration.collapsed(
                    hintText: 'Enter a prompt...',
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),

              // IconButton(
              //   onPressed: () {
              //     // chatProvider.sendMessage();
              //   },
              //   icon: const Icon(CupertinoIcons.paperplane),
              // ),

              GestureDetector(
                onTap: () {
                  if (textController.text.isNotEmpty) {
                    // Send the Message
                    sendChatMessage(
                      message: textController.text,
                      chatProvider: widget.chatProvider,
                      isTextOnly: hasImages ? false : true,
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.all(5.0),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      // CupertinoIcons.paperplane,
                      CupertinoIcons.up_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
