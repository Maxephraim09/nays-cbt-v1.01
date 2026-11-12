import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF1B4D3E);
  static const deepGreen = Color(0xFF0F3A2E);
  static const gold = Color(0xFFE9B741);
  static const paper = Color(0xFFF1FAF8);
  static const ink = Color(0xFF17231E);
  static const muted = Color(0xFF68766F);
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);
  static Color brand(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: brightness,
      primary: dark ? const Color(0xFF7BC2A5) : forest,
      secondary: gold,
      surface: dark ? const Color(0xFF18221D) : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B1513) : paper,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0B1513) : paper,
        foregroundColor: dark ? Colors.white : ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF202C25) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? Colors.white12 : const Color(0xFFE5EAE5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? Colors.white12 : const Color(0xFFE5EAE5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: forest, width: 1.5),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: dark ? Colors.white : ink,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.12,
        ),
        headlineMedium: TextStyle(
          color: dark ? Colors.white : ink,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: dark ? Colors.white : ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: dark ? Colors.white : ink,
          fontSize: 15,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: dark ? Colors.white70 : muted,
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }
}
