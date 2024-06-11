import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/widgets/bottom_chat_field.dart';
// import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Controller for the Input Field
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            centerTitle: true,
            title: const Text('Chat with Gemini'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child: chatProvider.inChatMessages.isEmpty
                        ? const Center(
                            child: Text('No Messages Yet'),
                          )
                        : ListView.builder(
                            itemCount: chatProvider.inChatMessages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  chatProvider.inChatMessages[index];
                              return ListTile(
                                title: Text(message.message.toString()),
                              );
                            },
                          ),
                  ),

                  // ? //  Input Field
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: TextField(
                  //         controller: _messageController,
                  //         decoration: const InputDecoration(
                  //           hintText: 'Type a message',
                  //         ),
                  //       ),
                  //     ),
                  //     IconButton(
                  //         onPressed: () {
                  //           // chatProvider.sendMessage();
                  //         },
                  //         icon: const Icon(CupertinoIcons.paperplane))
                  //   ],
                  // ),

                  BottomChatField(chatProvider: chatProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
