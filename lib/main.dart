import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'features/servers/data/server_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await ServerStore.ensureBoxes();

  const tvMode = String.fromEnvironment('TV_MODE');
  final isTv = tvMode == 'ON';

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ServerStore(isTvMode: isTv)..load()),
    ],
    child: const JellydeskApp(),
  ));
}
