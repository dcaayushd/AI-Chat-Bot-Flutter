import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BottomChatField extends StatefulWidget {
  const BottomChatField({super.key, required this.chatProvider,});

final ChatProvider chatProvider;

  @override
  State<BottomChatField> createState() => _BottomChatFieldState();
}

class _BottomChatFieldState extends State<BottomChatField> {
  // Controller for the Input Field
  final TextEditingController textController = TextEditingController();

  // Focus Node for the input field
  final FocusNode textFieldFocus = FocusNode();

  @override
  void dispose() {
    textController.dispose();
    textFieldFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // ! Pick an Image
            },
            icon: const Icon(CupertinoIcons.photo),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              focusNode: textFieldFocus,
              controller: textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (String value) {},
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
            onTap: (){
              // Send the Message
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
          )
        ],
      ),
    );
  }
}
