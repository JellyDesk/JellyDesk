import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jellydesk/features/playback/presentation/splash_page.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/servers/data/server_store.dart';
import 'features/splash/presentation/splash_page.dart' hide AnimatedSplashPage;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await ServerStore.ensureBoxes();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
     try {
       await windowManager.ensureInitialized();
       await windowManager.setTitle('JellyDesk');
     } catch (_) {
     }
   }

  // TV-Flag via --dart-define=TV_MODE=ON
  const tvMode = String.fromEnvironment('TV_MODE');
  final isTv = tvMode == 'ON';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ServerStore(isTvMode: isTv)..load(),
        ),
      ],
      child: const _RootWithSplash(),
    ),
  );
}

/// Zeigt zuerst den animierten Splash, danach deine JellydeskApp.
class _RootWithSplash extends StatefulWidget {
  const _RootWithSplash({super.key});
  @override
  State<_RootWithSplash> createState() => _RootWithSplashState();
}

class _RootWithSplashState extends State<_RootWithSplash> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Kurze Mindestdauer fürs Splash-Erlebnis; parallel kann deine App initialisieren.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: AnimatedSplashPage(
          // Wenn du nach echter Init weiterleiten willst,
          // ersetze das Delayed oben durch:
          // onFinished: () => setState(() => _ready = true),
        ),
      );
    }

    // Danach deine eigentliche App (mit Routing, Theme, etc.)
    return const JellydeskApp();
  }
}
