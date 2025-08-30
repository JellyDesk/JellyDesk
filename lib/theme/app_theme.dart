import 'package:flutter/material.dart';

class _Pair {
  final ThemeData light;
  final ThemeData dark;
  _Pair(this.light, this.dark);
}

_Pair buildAppTheme() {
  const seed = Color(0xFF6A5ACD);
  final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
  final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
  return _Pair(light, dark);
}
