import 'package:flutter/material.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class JellydeskApp extends StatelessWidget {
  const JellydeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    final theme = buildAppTheme();
    return MaterialApp.router(
      title: 'Jellydesk',
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
