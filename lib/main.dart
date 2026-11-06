import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'data/device.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Radio în fundal, cu control din notificare și de pe ecranul blocat.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'ro.kidtoon.app.radio',
      androidNotificationChannelName: 'Radio',
      androidNotificationOngoing: true,
    );
  } catch (_) {
    // Fără notificare de control (de ex. în previzualizarea web); restul aplicației merge.
  }
  await Device.detect();
  // Același comportament pe toate versiunile de Android (pe Android 15+ edge-to-edge e obligatoriu).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(KidToonApp(state: AppState(prefs)));
}

class KidToonApp extends StatelessWidget {
  const KidToonApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KidToon',
      debugShowCheckedModeBanner: false,
      theme: kidTheme(),
      // Telecomanda: OK (select) apasă butonul ales, ca Enter.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
      },
      home: ListenableBuilder(
        listenable: state,
        // Prima pornire: copilul își alege prietenul (numele, băiat sau fată, costumașul).
        builder: (context, _) => state.characterChosen ? MainScreen(state: state) : WelcomeScreen(state: state),
      ),
    );
  }
}
