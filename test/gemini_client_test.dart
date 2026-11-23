import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/models/chat_mode.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('decodes split SSE frames, discards thoughts, and preserves text whitespace', () async {
    final image = ChatImage.fromBytes(
      'relabelled.jpg',
      MockClient.pngResponse().bodyBytes,
    );
    final abort = Completer<void>();
    final wire = utf8.encode(
      ':heartbeat\r\n\r\n'
      'data: {"candidates":[{"content":{"parts":[{"thought":true,"text":"hidden"},\r\n'
      'data: {"text":"Hello "}]}}]}\r\n\r\n'
      'data: {"candidates":[{"content":{"parts":[{"text":"世界"}]},'
      '"finishReason":"MAX_TOKENS"}]}\n\n',
    );
    final transport = MockClient.streaming((request, body) async {
      expect(request.url.host, 'generativelanguage.googleapis.com');
      expect(
        request.url.path,
        '/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent',
      );
      expect(request.url.queryParameters, {'alt': 'sse'});
      expect(request.headers['x-goog-api-key'], 'test-key');
      expect(request.followRedirects, isFalse);
      expect(
        (request as http.AbortableRequest).abortTrigger,
        same(abort.future),
      );

      final data = jsonDecode(await body.bytesToString()) as Map;
      expect(
        (data['systemInstruction']['parts'] as List).map(
          (part) => part['text'],
        ),
        contains(ChatMode.coding.instruction),
      );
      final contents = data['contents'] as List;
      expect(contents.map((entry) => entry['role']), ['user', 'model', 'user']);
      expect(contents.first['parts'], [
        {'text': 'First part'},
        {'text': 'Second part'},
        {
          'inlineData': {
            'mimeType': 'image/png',
            'data': base64Encode(image.bytes),
          },
        },
      ]);

      return http.StreamedResponse(
        Stream.fromIterable(wire.map((byte) => [byte])),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final gemini = GeminiClient(
      httpClient: transport,
      model: 'models/gemini-3.5-flash-lite',
    );
    addTearDown(gemini.close);

    final chunks = await gemini
        .streamReply(
          apiKey: 'test-key',
          mode: ChatMode.coding,
          turns: [
            const GeminiTurn(Role.user, 'First part'),
            GeminiTurn(Role.user, 'Second part', [image]),
            const GeminiTurn(Role.assistant, 'Previous answer'),
            const GeminiTurn(Role.user, 'Follow-up'),
          ],
          abort: abort.future,
        )
        .toList();

    expect(chunks.map((chunk) => chunk.text).join(), 'Hello 世界');
    expect(chunks.last.truncated, isTrue);
    expect(chunks.last.finished, isTrue);
  });

  test('rejects mislabeled PDFs and unreadable text files', () {
    expect(
      () => ChatDocument.fromBytes(
        'image.pdf',
        MockClient.pngResponse().bodyBytes,
      ),
      throwsA(isA<ChatException>()),
    );
    expect(
      () => ChatDocument.fromBytes(
        'text.txt',
        Uint8List.fromList([0xff, 0xfe, 0xff]),
      ),
      throwsA(isA<ChatException>()),
    );
    expect(
      () => ChatDocument.fromBytes(
        'notes.md',
        Uint8List.fromList(utf8.encode('a' * 20001)),
      ),
      throwsA(isA<ChatException>()),
    );
  });

  test('maps quota responses without exposing their raw body', () async {
    final gemini = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response('sensitive request details', 429),
      ),
    );
    addTearDown(gemini.close);
    final output = gemini.streamReply(
      apiKey: 'test-key',
      mode: ChatMode.general,
      turns: const [GeminiTurn(Role.user, 'Hello')],
      abort: Completer<void>().future,
    );
    await expectLater(
      output,
      emitsError(
        isA<ChatException>().having(
          (error) => error.message,
          'message',
          contains('quota'),
        ),
      ),
    );
  });

  test('identifies API key rejection from a structured Gemini error', () async {
    final gemini = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"code":400,"message":"private server detail",'
          '"details":[{"reason":"API_KEY_INVALID"}]}}',
          400,
        ),
      ),
    );
    addTearDown(gemini.close);

    await expectLater(
      gemini.streamReply(
        apiKey: 'fake-key',
        mode: ChatMode.general,
        turns: const [GeminiTurn(Role.user, 'Hello')],
        abort: Completer<void>().future,
      ),
      emitsError(
        isA<ChatException>().having(
          (error) => error.message,
          'message',
          'Gemini rejected the API key. Check your key in .env or Settings.',
        ),
      ),
    );
  });

  test('rejects arbitrary bytes given an image filename', () {
    expect(
      () => ChatImage.fromBytes(
        'wrong.png',
        Uint8List.fromList(utf8.encode('plain text')),
      ),
      throwsA(isA<ChatException>()),
    );
  });

  test('reports a stream without a finish reason as interrupted', () async {
    final gemini = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          'data: {"candidates":[{"content":{"parts":[{"text":"Partial"}]}}]}\n\n',
          200,
        ),
      ),
    );
    addTearDown(gemini.close);
    final output = gemini.streamReply(
      apiKey: 'test-key',
      mode: ChatMode.general,
      turns: const [GeminiTurn(Role.user, 'Hello')],
      abort: Completer<void>().future,
    );
    await expectLater(
      output,
      emitsInOrder([
        isA<GeminiChunk>().having((chunk) => chunk.text, 'text', 'Partial'),
        emitsError(
          isA<ChatException>().having(
            (error) => error.message,
            'message',
            contains('ended the reply early'),
          ),
        ),
        emitsDone,
      ]),
    );
  });
}
