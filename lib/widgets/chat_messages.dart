import 'package:flutter/material.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/widgets/assistant_message_widget.dart';
import 'package:chatbotapp/widgets/my_message_widget.dart';

class ChatMessages extends StatelessWidget {
  const ChatMessages({
    super.key,
    required this.scrollController,
    required this.chatProvider,
    this.bottomPadding = 24,
  });

  final ScrollController scrollController;
  final ChatProvider chatProvider;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      itemCount: chatProvider.inChatMessages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final message = chatProvider.inChatMessages[index];
        return message.role.name == Role.user.name
            ? MyMessageWidget(message: message)
            : AssistantMessageWidget(message: message);
      },
    );
  }
}
