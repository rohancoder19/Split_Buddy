import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: const Color(0xFF5BC5A7), // Splitwise teal/green
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5BC5A7),
        primary: const Color(0xFF5BC5A7),
        secondary: const Color(0xFFFF652F), // Orange accent for owes
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF5BC5A7),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF5BC5A7),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5BC5A7),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
