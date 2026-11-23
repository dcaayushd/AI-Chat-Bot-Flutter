import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/chat_repository.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _event(String text, {bool done = true}) {
  final json = jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
        if (done) 'finishReason': 'STOP',
      },
    ],
  });
  return 'data: $json\n\n';
}

void main() {
  final repository = ChatRepository();

  setUpAll(() => Hive.registerAdapter(ChatHistoryAdapter()));

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('flutter-chat-tests-');
    Hive.init(dir.path);
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    await Hive.openLazyBox<Map>(Constants.chatImagesBox);
  });

  ChatProvider createChat(
    http.Client httpClient, {
    bool Function()? shouldSaveHistory,
  }) {
    final provider = ChatProvider(
      gemini: GeminiClient(httpClient: httpClient),
      repository: repository,
      developmentKey: 'test-key',
      shouldSaveHistory: shouldSaveHistory,
    );
    addTearDown(provider.dispose);
    return provider;
  }

  test(
    'keeps multimodal context across private turns without writing to disk',
    () async {
      var saveHistory = false;
      final requests = <List>[];
      final provider = createChat(
        MockClient((request) async {
          requests.add(jsonDecode(request.body)['contents'] as List);
          return http.Response(_event('A useful answer'), 200);
        }),
        shouldSaveHistory: () => saveHistory,
      );
      provider.setMode(ChatMode.study);
      final image = ChatImage.fromBytes(
        'test.png',
        MockClient.pngResponse().bodyBytes,
      );

      await provider.send('First question', images: [image]);
      saveHistory = true;
      await provider.send('What about the image?');
      final first = requests.last[0] as Map;
      final second = requests.last[1] as Map;
      expect(first['role'], 'user');
      expect(first['parts'][1]['inlineData']['mimeType'], 'image/png');
      expect(second['role'], 'model');
      expect(requests.last.last['parts'], [
        {'text': 'What about the image?'},
      ]);
      expect(provider.historyOff, isTrue);
      expect(Boxes.getChatHistory().isEmpty, isTrue);
      expect(Hive.lazyBox<Map>(Constants.chatImagesBox).isEmpty, isTrue);

      await provider.newChat();
      await provider.send('A separate conversation');
      expect(requests.last, hasLength(1));
      expect(Boxes.getChatHistory().length, 1);
    },
  );

  test(
    'a failed prompt survives a restart and retries without duplication',
    () async {
      final offline = createChat(
        MockClient((_) async => http.Response('{}', 503)),
      );
      await offline.send('Question that should be kept');
      final chatId = offline.currentChatId;
      expect(offline.generationError, contains('temporarily unavailable'));
      final box = Boxes.getChatHistory();
      await box.close();
      await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);

      var fail = false;
      final requests = <List>[];
      final resumed = createChat(
        MockClient((request) async {
          requests.add(jsonDecode(request.body)['contents'] as List);
          return fail
              ? http.Response('{}', 503)
              : http.Response(_event('Recovered answer'), 200);
        }),
      );
      await resumed.openChat(chatId);
      final promptId = resumed.messages.single.messageId;
      expect(resumed.hasUnansweredPrompt, isTrue);
      await resumed.retryLastReply();
      expect(resumed.messages.map((message) => message.text), [
        'Question that should be kept',
        'Recovered answer',
      ]);
      expect(resumed.messages.first.messageId, promptId);

      fail = true;
      await resumed.retryLastReply();
      expect(requests.last, hasLength(1));
      expect(resumed.messages.last.text, 'Recovered answer');
      expect(
        await repository.loadMessages(repository.getChat(chatId)!),
        hasLength(2),
      );
    },
  );

  test('stop aborts a request and commits the visible partial reply', () async {
    final incoming = StreamController<List<int>>();
    late http.AbortableRequest request;
    final receivedText = Completer<void>();
    final provider = createChat(
      MockClient.streaming((outgoing, body) async {
        request = outgoing as http.AbortableRequest;
        await body.drain<void>();
        incoming.add(utf8.encode(_event('Partial answer', done: false)));
        return http.StreamedResponse(incoming.stream, 200);
      }),
    );
    provider.addListener(() {
      if (provider.streamingReply?.text == 'Partial answer' &&
          !receivedText.isCompleted) {
        receivedText.complete();
      }
    });

    final generation = provider.send('Prompt');
    await receivedText.future;
    expect(provider.canStop, isTrue);
    provider.stopGeneration();
    await request.abortTrigger;
    await generation;
    await incoming.close();

    expect(provider.isBusy, isFalse);
    expect(provider.generationError, isNull);
    expect(provider.messages.last.text, 'Partial answer');
    expect(provider.messages.last.status, ReplyStatus.stopped);
    final saved = await repository.loadMessages(
      repository.getChat(provider.currentChatId)!,
    );
    expect(saved.last.status, ReplyStatus.stopped);
  });

  test('recovers readable turns beside damaged legacy entries and retains metadata', () async {
    const chatId = 'legacy-chat';
    const legacyBoxName = Constants.chatMessagesBox + chatId;
    final oldMessages = await Hive.openBox(legacyBoxName);
    final now = DateTime.now();
    await oldMessages.add({'role': 99, 'message': 'Incomplete legacy record'});
    for (final entry in [
      'Detailed old question',
      'Earlier reply',
      'Recent ask',
      'Recent response',
    ].indexed) {
      final (index, text) = entry;
      await oldMessages.add({
        'messageId': '$index',
        'chatId': chatId,
        'role': index.isEven ? 0 : 1,
        'message': text,
        'imagesUrls': <String>[],
        'timeSent': now.toIso8601String(),
      });
    }
    await Boxes.getChatHistory().put(
      chatId,
      ChatHistory(
        chatId: chatId,
        prompt: 'Recent ask',
        response: 'Recent response',
        imagesUrls: [],
        timestamp: now,
      ),
    );
    final provider = createChat(
      MockClient((_) async => http.Response(_event('Current answer'), 200)),
    );
    expect(
      await provider.searchChats([repository.getChat(chatId)!], 'detailed old'),
      hasLength(1),
    );
    await provider.openChat(chatId);
    expect(provider.messages, hasLength(4));
    await provider.renameChat(chatId, 'Research notes');
    await provider.togglePin(chatId);
    provider.setMode(ChatMode.writing);
    final image = ChatImage.fromBytes(
      'new.png',
      MockClient.pngResponse().bodyBytes,
    );
    await provider.send('Continue here', images: [image]);

    final saved = repository.getChat(chatId)!;
    expect(saved.displayTitle, 'Research notes');
    expect(saved.isPinned, isTrue);
    expect(saved.mode, ChatMode.writing.name);
    expect(await provider.searchChats([saved], 'earlier reply'), hasLength(1));
    final storedImage = await repository.loadImage(
      chatId,
      saved.imagesUrls.single,
    );
    expect(storedImage?.bytes, image.bytes);
    expect(
      await repository.loadImage('another-chat', saved.imagesUrls.single),
      isNull,
    );
    expect(
      await provider.exportSavedChat(saved),
      contains('[1 attached image]'),
    );

    await provider.deleteChat(chatId);
    expect(repository.getChat(chatId), isNull);
    expect(await Hive.boxExists(legacyBoxName), isFalse);
    expect(Hive.lazyBox<Map>(Constants.chatImagesBox).isEmpty, isTrue);
  });

  test(
    'clears orphaned legacy data while a private reply keeps streaming',
    () async {
      final localDirectory = File(Boxes.getChatHistory().path!).parent;
      final orphanedPhoto = File.fromUri(
        localDirectory.uri.resolve('chat_media/orphan/image.png'),
      );
      await orphanedPhoto.create(recursive: true);
      final otherFile = File.fromUri(
        localDirectory.uri.resolve('unrelated.txt'),
      );
      await otherFile.create();
      const orphanedBoxName = Constants.chatMessagesBox + 'orphan';
      final orphanedBox = await Hive.openBox(orphanedBoxName);
      await orphanedBox.add({'message': 'An older unindexed message'});

      final incoming = StreamController<List<int>>();
      final streaming = Completer<void>();
      final chat = createChat(
        MockClient.streaming((_, body) async {
          await body.drain<void>();
          incoming.add(utf8.encode(_event('First part', done: false)));
          return http.StreamedResponse(incoming.stream, 200);
        }),
        shouldSaveHistory: () => false,
      );
      chat.addListener(() {
        if (chat.streamingReply?.text.isNotEmpty == true &&
            !streaming.isCompleted) {
          streaming.complete();
        }
      });
      final reply = chat.send('A private prompt');
      await streaming.future;
      await chat.clearAllChats();
      expect(chat.canStop, isTrue);
      expect(await orphanedPhoto.exists(), isFalse);
      expect(await Hive.boxExists(orphanedBoxName), isFalse);
      expect(await otherFile.exists(), isTrue);

      incoming.add(utf8.encode(_event(' and last part')));
      await reply;
      await incoming.close();
      expect(chat.messages.last.text, 'First part and last part');
      expect(Boxes.getChatHistory().isEmpty, isTrue);
    },
  );
}
