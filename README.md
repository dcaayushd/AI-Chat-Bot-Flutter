# AI Chatbot

A Flutter chat client for Gemini with streaming answers, image follow-ups, and on-device conversation history.

## Run locally

Use Flutter 3.50 for the verified build setup. Android uses Gradle 9.5 and JDK 17 or newer. iOS uses Swift Package Manager for Flutter plugins.

Create `.env` from `.env.example` if needed and set `API_KEY` to your personal Gemini API key. You can also set `GEMINI_MODEL` to override the default `gemini-3.5-flash-lite`. [Get a key in Google AI Studio](https://aistudio.google.com/apikey).

```sh
flutter pub get
flutter run
```

Debug runs read the Gemini settings from `.env` automatically. Restart the run after editing the file. **Settings → Gemini connection** also accepts a key for the current app session.

To use `.env` explicitly in a local profile or release run, pass it to Flutter.

```sh
flutter run --profile --dart-define-from-file=.env
```

Both debug assets and explicit build-time values are accessible to anyone with the resulting app. Use an authenticated server for a shared API key in a public deployment. [API key guidance](https://aistudio.google.com/docs/api-key).

## Chat

- Choose **General**, **Writing**, **Coding**, or **Study** to tailor replies and starter prompts.
- Watch answers as they stream. Stop a reply and keep the partial result, retry a failed turn, or regenerate the last reply.
- Attach up to four JPEG, PNG, WebP, HEIC, or HEIF images. The composer accepts up to 4 MB per image and 10 MB per message. Follow-ups include recent messages and images within the request budget.
- Use the microphone to dictate on platforms with speech recognition. Copy a reply, an individual code block, or an entire conversation as Markdown.
- Search saved conversations by title or any message, rename or pin them, and open them to continue. Existing Hive conversations can be reopened and searched.

**Save history** controls local storage. Turning it off keeps new turns and their images in memory for the current conversation. Use **Clear history** to delete existing saved conversations. Gemini receives the prompt and recent context whenever you send a message.

## Checks

```sh
flutter analyze
flutter test
```

Tests use a mocked Gemini transport for streaming, cancellation, retry, and configuration checks. Storage tests use temporary Hive databases to verify legacy chat and profile migration, deletion, and settings persistence.

## License

MIT. See [LICENSE](LICENSE).

Created by Aayush D.C Dangi (dcaayushd).
