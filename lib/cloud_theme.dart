import 'package:flutter/material.dart';

const cloudInk = Color(0xFF202A30);
const cloudMuted = Color(0xFF5D6B73);
const cloudBlue = Color(0xFF366D8B);
const cloudGround = Color(0xFFF2F6F8);

ThemeData cloudTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: cloudBlue)
      .copyWith(primary: cloudInk, surface: Colors.white, onSurface: cloudInk);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Instrument Sans',
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    dividerColor: const Color(0xFFE5EBEE),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5DEE3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5DEE3)),
      ),
      contentPadding: const EdgeInsets.all(16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cloudInk,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Instrument Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cloudInk,
        minimumSize: const Size(44, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: cloudInk,
        side: const BorderSide(color: Color(0xFFD5DEE3)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFEAF0F3),
      height: 72,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
