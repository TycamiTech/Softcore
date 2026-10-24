import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'core/local_audio_proxy.dart';
import 'core/theme.dart';
import 'data/repositories/music_repository.dart';
import 'data/services/local_db_service.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: ${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  };

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.softcore.audio.channel',
      androidNotificationChannelName: 'Softcore Playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground init error: $e');
  }

  // Inisialisasi In-App Local Audio Proxy untuk pemutaran langsung bebas throttling
  try {
    await LocalAudioProxy().start();
  } catch (e) {
    debugPrint('LocalAudioProxy start error: $e');
  }

  runApp(const SoftcoreApp());
}

class SoftcoreApp extends StatelessWidget {
  const SoftcoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalDbService>.value(value: LocalDbService()),
        Provider<MusicRepository>.value(value: MusicRepository()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'softcore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
