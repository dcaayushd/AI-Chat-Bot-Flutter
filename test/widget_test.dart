import 'package:flutter_test/flutter_test.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Chat screen renders empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
          ChangeNotifierProvider(create: (_) => VoiceInputProvider()),
        ],
        child: MaterialApp(
          home: const ChatScreen(),
          theme: ThemeData(useMaterial3: true),
        ),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
  });
}
