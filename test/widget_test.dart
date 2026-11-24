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
import 'package:chatbotapp/widgets/chat/conversation_outline.dart';
import 'package:chatbotapp/widgets/chat/chat_header.dart';

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

Future<void> _openWorkspaceStorage() async {
  final dir = await Directory.systemTemp.createTemp('chat-workspace-');
  addTearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ChatHistoryAdapter());
  await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
  await Hive.openLazyBox<Map>(Constants.chatImagesBox);
  await Hive.openBox<String>(Constants.chatDraftsBox);
  await Hive.openBox<Map>(Constants.chatProjectsBox);
}

Future<void> _tapAndWait(
  WidgetTester tester,
  ChatProvider chat,
  Finder action,
  bool Function() completed,
) async {
  await tester.runAsync(() async {
    final finished = Completer<void>();
    void handleAction() {
      if (completed() && !finished.isCompleted) finished.complete();
    }

    chat.addListener(handleAction);
    try {
      await tester.tap(action);
      handleAction();
      await finished.future.timeout(const Duration(seconds: 5));
    } finally {
      chat.removeListener(handleAction);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'creates, scopes, and moves conversations in the project workspace',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chat = ChatProvider(developmentKey: '');
      addTearDown(chat.dispose);
      const chatId = 'unassigned-thread';
      await tester.runAsync(() async {
        await _openWorkspaceStorage();
        final time = DateTime.now();
        await Hive.box<ChatHistory>(Constants.chatHistoryBox).put(
          chatId,
          ChatHistory(
            chatId: chatId,
            prompt: 'An unassigned discussion',
            response: 'A draft answer',
            imagesUrls: [],
            timestamp: time,
            transcript: [
              Message(
                messageId: 'prompt',
                chatId: chatId,
                role: Role.user,
                text: 'An unassigned discussion',
                timeSent: time,
              ).toMap(),
              Message(
                messageId: 'reply',
                chatId: chatId,
                role: Role.assistant,
                text: 'A draft answer',
                timeSent: time,
              ).toMap(),
            ],
          ),
        );
      });
      await tester.pumpWidget(_app(chat));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field('Project name'), 'Release plan');
      await tester.enterText(
        field('Project instructions'),
        'Keep action items specific.',
      );
      await tester.enterText(field('Reference notes'), 'The beta is internal.');
      await _tapAndWait(
        tester,
        chat,
        find.text('Save project'),
        () => !chat.isBusy && chat.projects.isNotEmpty,
      );
      final project = chat.projects.single;
      expect(project.referenceNotes, 'The beta is internal.');
      expect(find.text('An unassigned discussion'), findsNothing);
      await _tapAndWait(
        tester,
        chat,
        find.text('New chat'),
        () => !chat.isBusy && chat.currentProject?.id == project.id,
      );
      expect(
        find.descendant(
          of: find.byType(ChatHeader),
          matching: find.text('Release plan'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Release plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'All chats'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.tap(find.byTooltip('Conversation actions')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Move to project')));
      await tester.pumpAndSettle();
      final assignment = find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Release plan'),
      );
      await _tapAndWait(
        tester,
        chat,
        assignment,
        () =>
            !chat.isBusy &&
            Hive.box<ChatHistory>(Constants.chatHistoryBox)
                    .get(chatId)
                    ?.projectId ==
                project.id,
      );

      tester.view.physicalSize = const Size(390, 780);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 590);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Import conversation file'), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'All chats'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Release plan'));
      await tester.pumpAndSettle();
      await _tapAndWait(
        tester,
        chat,
        find.text('An unassigned discussion'),
        () => !chat.isBusy && chat.currentChatId == chatId,
      );
      expect(chat.currentProject?.id, project.id);
    },
  );

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
    expect(composer.controller?.text, startsWith('Help me write unit tests.'));
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

  testWidgets('searches, branches, and restores drafts in the workspace', (
    tester,
  ) async {
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
      await _openWorkspaceStorage();
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
    await _tapAndWait(
      tester,
      chat,
      find.byTooltip('Branch from this reply'),
      () => chat.currentChatId != sourceId && !chat.isBusy,
    );
    final branchId = chat.currentChatId;
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
    await _tapAndWait(
      tester,
      chat,
      historyTitle('Weekend plans'),
      () => chat.currentChatId == sourceId && !chat.isBusy,
    );
    expect(tester.widget<TextField>(composer).controller?.text, isEmpty);
    await _tapAndWait(
      tester,
      chat,
      historyTitle('Branch · Weekend plans'),
      () => chat.currentChatId == branchId && !chat.isBusy,
    );

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

  testWidgets('finds a distant message and reopens it from saved replies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = ChatProvider(developmentKey: '');
    addTearDown(chat.dispose);
    const chatId = 'long-chat';
    const target = 'Unique orchard result';
    const targetId = 'message-17';
    await tester.runAsync(() async {
      await _openWorkspaceStorage();
      final time = DateTime.now();
      final transcript = List.generate(
        84,
        (index) => Message(
          chatId: chatId,
          messageId: 'message-$index',
          role: index.isEven ? Role.user : Role.assistant,
          text: index == 17
              ? target
              : 'Notes on phase $index ${'with extra details ' * (index % 6)}',
          timeSent: time,
        ).toMap(),
      );
      await Hive.box<ChatHistory>(Constants.chatHistoryBox).put(
        chatId,
        ChatHistory(
          chatId: chatId,
          prompt: 'Project timeline',
          response: 'Final notes',
          timestamp: time,
          imagesUrls: [],
          transcript: transcript,
        ),
      );
      await chat.openChat(chatId);
    });
    await tester.pumpWidget(_app(chat));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Find in conversation'));
    await tester.pumpAndSettle();
    final outline = find.byType(ConversationOutline);
    expect(outline, findsOneWidget);
    final search = find.descendant(
      of: outline,
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'ORCHARD');
    await tester.pumpAndSettle();
    expect(find.text('1 match'), findsOneWidget);
    await tester.tap(find.descendant(of: outline, matching: find.text(target)));
    await tester.pumpAndSettle();
    final selected = find.byKey(const ValueKey('selected-message'));
    expect(
      find.descendant(of: selected, matching: find.text(target)),
      findsOneWidget,
    );
    final bookmark = find.descendant(
      of: selected,
      matching: find.byTooltip('Bookmark reply'),
    );
    await _tapAndWait(
      tester,
      chat,
      bookmark,
      () =>
          !chat.isBusy &&
          chat.messages.any(
            (message) =>
                message.messageId == targetId && message.bookmarkedAt != null,
          ),
    );

    await tester.tap(find.text('Saved replies'));
    await tester.pumpAndSettle();
    final saved = find.descendant(
      of: find.byType(ChatHistoryPanel),
      matching: find.text(target),
    );
    expect(saved, findsOneWidget);
    await _tapAndWait(
      tester,
      chat,
      find.text('New chat'),
      () => !chat.isBusy && !chat.hasMessages,
    );
    await _tapAndWait(
      tester,
      chat,
      saved,
      () => !chat.isBusy && chat.currentChatId == chatId,
    );
    expect(
      find.descendant(of: selected, matching: find.text(target)),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(380, 750);
    await tester.pumpAndSettle();
    expect(outline, findsNothing);
    await tester.tap(find.byTooltip('Find in conversation'));
    await tester.pumpAndSettle();
    expect(outline, findsOneWidget);
    await tester.enterText(search, 'phase 70');
    await tester.pumpAndSettle();
    final result = find.descendant(
      of: outline,
      matching: find.textContaining('Notes on phase 70'),
    );
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(outline, findsNothing);
    expect(
      find.descendant(
        of: selected,
        matching: find.textContaining('Notes on phase 70'),
      ),
      findsOneWidget,
    );
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
    final list = find.byType(CustomScrollView);
    final scroll = tester.widget<CustomScrollView>(list).controller!;
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
