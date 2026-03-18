import 'package:flutter_test/flutter_test.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Chat screen renders empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ChatProvider(),
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    expect(find.text('Chat with Gemini'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Enter a prompt...'), findsOneWidget);
  });
}
