import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/county_pavilion.dart';
import 'theme/stadium_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = CricketSettings();
  await settings.load();
  final audio = CricketAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(CricketApp(settings: settings, audio: audio));
}

class CricketApp extends StatefulWidget {
  final CricketSettings settings;
  final CricketAudio audio;
  const CricketApp({super.key, required this.settings, required this.audio});

  @override
  State<CricketApp> createState() => _CricketAppState();
}

class _CricketAppState extends State<CricketApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Cricket',
        debugShowCheckedModeBanner: false,
        theme: Pavilion.theme(StadiumThemes.byId(
          widget.settings.stadiumId,
          custom: widget.settings.customStadium,
        )),
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
