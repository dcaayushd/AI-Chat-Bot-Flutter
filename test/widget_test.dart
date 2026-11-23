import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/models/chat_options.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/screens/chat_history_screen.dart';
import 'package:chatbotapp/screens/chat_screen.dart';
import 'package:chatbotapp/themes/my_theme.dart';
import 'package:chatbotapp/widgets/bottom_chat_field.dart';

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

  testWidgets('configures, continues, and restores a reply on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Map>[];
    final chat = ChatProvider(
      gemini: GeminiClient(
        httpClient: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map);
          final first = requests.length == 1;
          final payload = jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': first ? 'Part one' : ' and part two.'},
                  ],
                },
                'finishReason': first ? 'MAX_TOKENS' : 'STOP',
              },
            ],
          });
          return http.Response('data: $payload\n\n', 200);
        }),
      ),
      developmentKey: 'test-key',
      shouldSaveHistory: () => false,
    );
    addTearDown(chat.dispose);
    await tester.pumpWidget(_app(chat, themeMode: ThemeMode.dark));

    Future<void> tapAndAwaitReply(Finder action) async {
      await tester.runAsync(() async {
        final done = Completer<void>();
        var started = false;
        void listen() {
          if (chat.isGenerating) {
            started = true;
          } else if (started && !done.isCompleted) {
            done.complete();
          }
        }

        chat.addListener(listen);
        try {
          await tester.tap(action);
          await done.future.timeout(const Duration(seconds: 5));
        } finally {
          chat.removeListener(listen);
        }
      });
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concise').last);
    await tester.pumpAndSettle();
    final instructions = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(instructions, 'Use plain language.');
    await tester.tap(find.text('Save options'));
    await tester.pumpAndSettle();
    expect(chat.options.length, ReplyLength.concise);

    await tester.enterText(find.byType(TextField), 'Write two parts');
    await tester.pump();
    await tapAndAwaitReply(find.byTooltip('Send message'));
    expect(
      (requests.single['systemInstruction']['parts'] as List).map(
        (part) => part['text'],
      ),
      contains('Use plain language.'),
    );
    expect(
      requests.single['generationConfig']['maxOutputTokens'],
      ReplyLength.concise.maxOutputTokens,
    );
    expect(chat.generationError, isNull);
    expect(chat.messages.last.role, Role.assistant);
    expect(chat.messages.last.status, ReplyStatus.truncated);
    expect(chat.canContinueLastReply, isTrue);
    await tapAndAwaitReply(find.text('Continue reply'));
    expect(chat.messages.last.text, 'Part one and part two.');

    await tester.tap(find.byTooltip('Reply versions'));
    await tester.pumpAndSettle();
    expect(find.text('Earlier reply 1'), findsOneWidget);
    await tester.tap(find.text('Use this version'));
    await tester.pumpAndSettle();
    expect(chat.messages.last.text, 'Part one');
    expect(find.text('Continue reply'), findsOneWidget);
  });

  testWidgets('searches and branches in the wide workspace', (tester) async {
    tester.view.physicalSize = const Size(1240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reply = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'An outline of the project'},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    });
    final chat = ChatProvider(
      gemini: GeminiClient(
        httpClient: MockClient(
          (_) async => http.Response('data: $reply\n\n', 200),
        ),
      ),
      developmentKey: 'test-key',
    );
    addTearDown(chat.dispose);
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('chat-workspace-');
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
      Hive.init(dir.path);
      Hive.registerAdapter(ChatHistoryAdapter());
      await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
      await Hive.openLazyBox<Map>(Constants.chatImagesBox);
      await chat.send('Roadmap');
      await chat.newChat();
      await chat.send('Weekend plans');
    });
    await tester.pumpWidget(_app(chat));
    await tester.pumpAndSettle();

    final sidebar = find.byType(ChatHistoryPanel);
    final search = find.descendant(
      of: sidebar,
      matching: find.byType(TextField),
    );
    Finder historyTitle(String value) =>
        find.descendant(of: sidebar, matching: find.text(value));
    expect(historyTitle('Roadmap'), findsOneWidget);
    expect(historyTitle('Weekend plans'), findsOneWidget);

    await tester.enterText(search, 'outline');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(historyTitle('Roadmap'), findsOneWidget);
    expect(historyTitle('Weekend plans'), findsOneWidget);

    await tester.enterText(search, 'weekend');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(historyTitle('Roadmap'), findsNothing);
    expect(historyTitle('Weekend plans'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    final sourceId = chat.currentChatId;
    await tester.runAsync(() async {
      final branchOpened = Completer<void>();
      void handleBranch() {
        if (chat.currentChatId != sourceId &&
            !chat.isBusy &&
            !branchOpened.isCompleted) {
          branchOpened.complete();
        }
      }

      chat.addListener(handleBranch);
      try {
        await tester.tap(find.byTooltip('Branch from this reply'));
        await branchOpened.future.timeout(const Duration(seconds: 5));
      } finally {
        chat.removeListener(handleBranch);
      }
    });
    await tester.pumpAndSettle();
    expect(chat.title, 'Branch · Weekend plans');
    expect(historyTitle('Weekend plans'), findsOneWidget);
    expect(historyTitle('Branch · Weekend plans'), findsOneWidget);

    await tester.tap(find.byTooltip('Prompt actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit in a branch'));
    await tester.pumpAndSettle();
    final editField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(editField).controller?.text,
      'Weekend plans',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final composer = find.descendant(
      of: find.byType(BottomChatField),
      matching: find.byType(TextField),
    );
    await tester.enterText(composer, 'An unsent follow-up');
    await tester.tap(historyTitle('Weekend plans'));
    await tester.pumpAndSettle();
    expect(find.text('The current draft will be discarded.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(sidebar, findsNothing);
    expect(find.byTooltip('History'), findsOneWidget);
    expect(
      tester.widget<TextField>(composer).controller?.text,
      'An unsent follow-up',
    );
    expect(tester.takeException(), isNull);
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
