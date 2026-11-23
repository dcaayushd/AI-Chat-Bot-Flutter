import 'package:chatbotapp/apis/gemini_client.dart';
import 'package:chatbotapp/apis/gemini_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:chatbotapp/themes/my_theme.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/hive/chat_repository.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<GeminiConfig> _initialization = _initialize();

  Future<GeminiConfig> _initialize() async {
    final config = await GeminiConfig.load();
    await ChatRepository.initialize();
    return config;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GeminiConfig>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.data case final config?) return _chatApp(config);
        final failed =
            snapshot.connectionState == ConnectionState.done &&
            snapshot.hasError;
        return MaterialApp(
          title: Constants.appTitle,
          theme: lightTheme,
          darkTheme: darkTheme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: failed
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not open local app storage.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _initialization = _initialize()),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(
                      semanticsLabel: 'Opening AI Chatbot',
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _chatApp(GeminiConfig geminiConfig) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (context) => SettingsProvider()..getSavedSettings(),
      ),
      ChangeNotifierProvider(
        create: (context) {
          final settings = context.read<SettingsProvider>();
          return ChatProvider(
            gemini: GeminiClient(model: geminiConfig.model),
            developmentKey: geminiConfig.apiKey,
            shouldSaveHistory: () => settings.saveChatHistory,
          );
        },
      ),
      ChangeNotifierProvider(
        create: (context) => UserProfileProvider()..loadUser(),
      ),
      ChangeNotifierProvider(create: (context) => VoiceInputProvider()),
    ],
    child: const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return MaterialApp(
      title: Constants.appTitle,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settingsProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
