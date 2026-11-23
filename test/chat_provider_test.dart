import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/chat_history.dart';
import 'package:chatbotapp/hive/chat_repository.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/chat_options.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _event(String text, {bool done = true, String finish = 'STOP'}) {
  final json = jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
        if (done) 'finishReason': finish,
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
    'reopens chat options and revises a document prompt in a separate branch',
    () async {
      final requests = <Map>[];
      MockClient transport() => MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map);
        return http.Response(_event('Answer ${requests.length}'), 200);
      });
      final source = createChat(transport());
      final notes = ChatDocument.fromBytes(
        'notes.md',
        Uint8List.fromList(utf8.encode('# Test plan')),
      );
      final pdf = ChatDocument.fromBytes(
        'sample.pdf',
        Uint8List.fromList(utf8.encode('%PDF-1.7\n')),
      );
      await source.send('Give me a study strategy');
      await source.send('Explain these references', documents: [notes, pdf]);
      await source.send('A later question');
      final sourceId = source.currentChatId;
      const options = ChatOptions(
        length: ReplyLength.detailed,
        instructions: 'Use concrete examples.',
      );
      await source.updateOptions(options);
      await source.renameChat(sourceId, 'Project notes');

      final history = Boxes.getChatHistory();
      await history.close();
      await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
      final reopened = createChat(transport());
      await reopened.openChat(sourceId);
      expect(reopened.options, options);
      final originalReferences = reopened.messages[2].documentRefs;

      await reopened.editPromptInBranch(
        reopened.messages[2].messageId,
        'Explain the tradeoffs',
      );
      final branchId = reopened.currentChatId;
      expect(branchId, isNot(sourceId));
      expect(reopened.messages.map((message) => message.text), [
        'Give me a study strategy',
        'Answer 1',
        'Explain the tradeoffs',
        'Answer 4',
      ]);
      expect(reopened.options, options);
      expect(
        ChatOptions.fromMap(repository.getChat(branchId)?.options),
        options,
      );
      expect(
        requests.last['generationConfig']['maxOutputTokens'],
        ReplyLength.detailed.maxOutputTokens,
      );
      expect(
        (requests.last['systemInstruction']['parts'] as List).map(
          (part) => part['text'],
        ),
        contains(options.instructions),
      );
      expect(requests.last['contents'].last['parts'], [
        {'text': 'Explain the tradeoffs'},
        {'text': 'Attached file "notes.md"\n# Test plan'},
        {'text': 'Attached file "sample.pdf"'},
        {
          'inlineData': {
            'mimeType': 'application/pdf',
            'data': base64Encode(pdf.bytes),
          },
        },
      ]);
      final original = await repository.loadMessages(
        repository.getChat(sourceId)!,
      );
      expect(original[2].text, 'Explain these references');
      expect(original[4].text, 'A later question');

      final copiedReferences = reopened.messages[2].documentRefs;
      expect(copiedReferences, isNot(originalReferences));
      await reopened.deleteChat(sourceId);
      final surviving = await reopened.attachmentFor(
        branchId,
        copiedReferences.first,
      ) as ChatDocument;
      expect(surviving.text, notes.text);
      expect(reopened.exportCurrentChat(), contains('[2 attached documents]'));
      expect(
        await repository.loadAttachment(sourceId, originalReferences.first),
        isNull,
      );
    },
  );

  test('continues and regenerates without duplicating prompts, then restores a saved version', () async {
    final requests = <List>[];
    final chat = createChat(
      MockClient((request) async {
        requests.add(jsonDecode(request.body)['contents'] as List);
        return switch (requests.length) {
          1 => http.Response(_event('Part one', finish: 'MAX_TOKENS'), 200),
          2 => http.Response('{}', 503),
          3 => http.Response(_event(' and part two.'), 200),
          _ => http.Response(_event('A different answer'), 200),
        };
      }),
    );
    await chat.send('A wide topic');
    final answerId = chat.messages.last.messageId;
    expect(chat.canContinueLastReply, isTrue);
    await chat.continueLastReply();
    expect(chat.messages.last.text, 'Part one');
    expect(chat.messages.last.previousReplies, isEmpty);
    expect(chat.generationError, contains('temporarily unavailable'));

    await chat.retryLastReply(afterError: true);
    expect(requests.last.map((turn) => turn['role']), [
      'user',
      'model',
      'user',
    ]);
    expect(requests.last[1]['parts'], [
      {'text': 'Part one'},
    ]);
    expect(requests.last.last['parts'].single['text'], startsWith('Continue'));
    expect(chat.messages, hasLength(2));
    expect(chat.messages.last.text, 'Part one and part two.');
    expect(
      chat.messages.last.previousReplies.single.status,
      ReplyStatus.truncated,
    );
    expect(chat.canContinueLastReply, isFalse);

    await chat.retryLastReply();
    expect(requests.last, hasLength(1));
    expect(chat.messages.last.messageId, answerId);
    expect(chat.messages.last.text, 'A different answer');
    expect(chat.messages.last.previousReplies, hasLength(2));
    final partial = chat.messages.last.previousReplies.last;
    await chat.restoreReply(answerId, partial);
    expect(chat.messages.last.text, 'Part one');
    expect(chat.canContinueLastReply, isTrue);
    expect(requests, hasLength(4));

    final reopened = createChat(
      MockClient((_) async => http.Response(_event('Fresh answer'), 200)),
    );
    await reopened.openChat(chat.currentChatId);
    expect(reopened.messages.last.status, ReplyStatus.truncated);
    expect(reopened.messages.last.previousReplies.map((r) => r.text), [
      'A different answer',
      'Part one and part two.',
    ]);
    for (var attempt = 0; attempt < 5; attempt++) {
      await reopened.retryLastReply();
    }
    expect(
      reopened.messages.last.previousReplies,
      hasLength(Message.maxPreviousReplies),
    );
  });

  test(
    'reports omitted earlier documents and keeps current attachments required',
    () async {
      final calls = <List>[];
      final provider = createChat(
        MockClient((request) async {
          calls.add(jsonDecode(request.body)['contents'] as List);
          return http.Response(_event('Reply'), 200);
        }),
      );
      final doc = ChatDocument.fromBytes(
        'draft.txt',
        Uint8List.fromList(utf8.encode('Document body')),
      );
      final media = Hive.lazyBox<Map>(Constants.chatImagesBox);
      await provider.send('Use the draft', documents: [doc]);
      await media.delete(provider.messages.first.documentRefs.single);
      await provider.send('Use this current file', documents: [doc]);
      expect(provider.messages.last.contextLimited, isTrue);
      expect(calls.last.first['parts'], [
        {'text': 'Use the draft'},
      ]);
      expect(calls.last.last['parts'].last['text'], contains('Document body'));
      await media.delete(provider.messages[2].documentRefs.single);
      await provider.retryLastReply();
      expect(calls, hasLength(2));
      expect(provider.generationError, contains('attachment is unavailable'));
      expect(provider.messages.last.text, 'Reply');
    },
  );

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
      expect(provider.canBranch, isFalse);
      await expectLater(
        provider.branchFrom(provider.messages.last.messageId),
        throwsA(isA<ChatException>()),
      );
      expect(Boxes.getChatHistory().isEmpty, isTrue);
      expect(Hive.lazyBox<Map>(Constants.chatImagesBox).isEmpty, isTrue);

      await provider.newChat();
      await provider.send('A separate conversation');
      expect(requests.last, hasLength(1));
      expect(Boxes.getChatHistory().length, 1);
    },
  );

  test('a saved branch keeps earlier context and owns its images', () async {
    final requests = <List>[];
    MockClient transport() => MockClient((request) async {
      requests.add(jsonDecode(request.body)['contents'] as List);
      return http.Response(_event('Answer ${requests.length}'), 200);
    });
    final source = createChat(transport())..setMode(ChatMode.study);
    final image = ChatImage.fromBytes(
      'notes.png',
      MockClient.pngResponse().bodyBytes,
    );
    await source.send('Explain these notes', images: [image]);
    await source.send('Details beyond the branch point');
    final sourceId = source.currentChatId;
    final sourceImage = source.messages.first.imagesUrls.single;
    await source.renameChat(sourceId, 'Study notes');
    await source.togglePin(sourceId);
    expect(source.title, 'Study notes');

    await source.branchFrom(source.messages[1].messageId);

    final branchId = source.currentChatId;
    expect(branchId, isNot(sourceId));
    expect(source.title, 'Branch · Study notes');
    expect(source.mode, ChatMode.study);
    expect(source.messages.map((message) => message.text), [
      'Explain these notes',
      'Answer 1',
    ]);
    expect(requests, hasLength(2));
    final branchImage = source.messages.first.imagesUrls.single;
    expect(branchImage, isNot(sourceImage));
    expect(repository.getChat(branchId)?.isPinned, isFalse);
    expect(repository.getChat(sourceId)?.isPinned, isTrue);
    expect(
      (await repository.loadMessages(repository.getChat(sourceId)!)),
      hasLength(4),
    );

    await source.deleteChat(sourceId);
    final reopened = createChat(transport());
    await reopened.openChat(branchId);
    expect(reopened.title, source.title);
    expect(
      (await reopened.imageFor(branchId, branchImage))?.bytes,
      image.bytes,
    );
    expect(await repository.loadImage(sourceId, sourceImage), isNull);

    await reopened.send('Make a practice quiz');
    expect(requests.last, hasLength(3));
    expect(
      requests.last.first['parts'][1]['inlineData']['mimeType'],
      'image/png',
    );
    expect(requests.last[1]['parts'], [
      {'text': 'Answer 1'},
    ]);
    expect(requests.last.last['parts'], [
      {'text': 'Make a practice quiz'},
    ]);
  });

  test('a branch with a missing image rolls back the copied media', () async {
    final chat = createChat(
      MockClient((_) async => http.Response(_event('An answer'), 200)),
    );
    final image = ChatImage.fromBytes(
      'notes.png',
      MockClient.pngResponse().bodyBytes,
    );
    await chat.send('Explain both images', images: [image, image]);
    final originalId = chat.currentChatId;
    final images = Hive.lazyBox<Map>(Constants.chatImagesBox);
    await images.delete(chat.messages.first.imagesUrls.last);

    await expectLater(
      chat.branchFrom(chat.messages.last.messageId),
      throwsA(isA<ChatException>()),
    );

    expect(chat.currentChatId, originalId);
    expect(chat.isBusy, isFalse);
    expect(Boxes.getChatHistory().keys, [originalId]);
    expect(images.keys, [chat.messages.first.imagesUrls.first]);
  });

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
