import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/screens/chat_screen.dart';
import 'package:chatbotapp/themes/my_theme.dart';

Widget _app(ChatProvider chat, {ThemeMode themeMode = ThemeMode.light}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: chat),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ChangeNotifierProvider(create: (_) => VoiceInputProvider()),
    ],
    child: MaterialApp(
      home: const ChatScreen(),
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
    ),
  );
}

void main() {
  testWidgets('selecting a response mode updates starter drafts', (
    tester,
  ) async {
    final chat = ChatProvider(developmentKey: '');
    addTearDown(chat.dispose);
    await tester.pumpWidget(_app(chat));

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a unit test'));
    await tester.pumpAndSettle();
    final composer = tester.widget<TextField>(find.byType(TextField));
    expect(composer.controller?.text, 'Write a unit test');
    expect(chat.hasMessages, isFalse);
  });

  testWidgets('opens Settings to connect with a session key', (tester) async {
    final chat = ChatProvider(developmentKey: '');
    addTearDown(chat.dispose);
    await tester.pumpWidget(_app(chat));

    await tester.tap(find.text('Connect Gemini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini connection'));
    await tester.pumpAndSettle();
    final keyField = tester.widget<TextField>(find.byType(TextField));
    expect(keyField.obscureText, isTrue);
    await tester.enterText(find.byType(TextField), 'widget-test-key');
    await tester.pump();
    await tester.tap(find.text('Use key'));
    await tester.pumpAndSettle();
    expect(chat.isConfigured, isTrue);
    expect(chat.hasSessionKey, isTrue);
  });

  testWidgets('renders a streaming code block and stops generation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final incoming = StreamController<List<int>>();
    final chat = ChatProvider(
      gemini: GeminiClient(
        httpClient: MockClient.streaming((request, body) async {
          await body.drain<void>();
          return http.StreamedResponse(incoming.stream, 200);
        }),
      ),
      developmentKey: 'test-key',
      shouldSaveHistory: () => false,
    );
    addTearDown(chat.dispose);
    await tester.pumpWidget(_app(chat, themeMode: ThemeMode.dark));
    await tester.enterText(find.byType(TextField), 'Show me a Dart example');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(find.byTooltip('Stop generating'), findsOneWidget);

    final fence = String.fromCharCodes([96, 96, 96]);
    final reply = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text':
                    '$fence'
                    'dart\nvoid main() {}\n$fence',
              },
            ],
          },
        },
      ],
    });
    incoming.add(utf8.encode('data: $reply\n\n'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byTooltip('Copy code'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop generating'));
    await tester.pumpAndSettle();
    await incoming.close();
    expect(find.text('Generation stopped'), findsOneWidget);
    expect(find.byTooltip('Regenerate reply'), findsOneWidget);
  });

  testWidgets('follows a growing reply until the reader scrolls back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final incoming = StreamController<List<int>>();
    final chat = ChatProvider(
      gemini: GeminiClient(
        httpClient: MockClient.streaming((request, body) async {
          await body.drain<void>();
          return http.StreamedResponse(incoming.stream, 200);
        }),
      ),
      developmentKey: 'test-key',
      shouldSaveHistory: () => false,
    );
    addTearDown(chat.dispose);
    await tester.pumpWidget(_app(chat));
    unawaited(chat.send('Write a long explanation'));
    await tester.pump();

    Future<void> writeParagraphs(int count) async {
      final text = List.generate(
        count,
        (i) => 'Paragraph $i with a few words.',
      ).join('\n\n');
      final reply = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '\n\n$text'},
              ],
            },
          },
        ],
      });
      incoming.add(utf8.encode('data: $reply\n\n'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump();
      await tester.pump();
    }

    await writeParagraphs(32);
    final list = find.byType(ListView);
    final scroll = tester.widget<ListView>(list).controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(400));
    expect(scroll.position.extentAfter, closeTo(0, 1));

    await tester.drag(list, const Offset(0, 265));
    await tester.pumpAndSettle();
    final readingPosition = scroll.offset;
    expect(find.byTooltip('Jump to latest'), findsOneWidget);

    await writeParagraphs(16);
    expect(scroll.offset, closeTo(readingPosition, 1));
    await tester.tap(find.byTooltip('Jump to latest'));
    await tester.pumpAndSettle();
    expect(scroll.position.extentAfter, closeTo(0, 1));

    chat.stopGeneration();
    await tester.pumpAndSettle();
    await incoming.close();
  });
}
