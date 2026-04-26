import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color backgroundgrey = Color(0xFFF0F4F8);
  static const Color texdark = Color(0xFF1A1A2E);
  static const Color textgrey = Color(0xFF9E9E9E);

  static ThemeData get theme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundgrey,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundgrey,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: texdark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
        iconTheme: IconThemeData(color: texdark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
    );
  }
}