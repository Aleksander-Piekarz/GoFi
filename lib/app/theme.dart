import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF121212);
  static const bgAlt = Color(0xFF1E1E1E);

  static const accent = Color(0xFFFD605B);
  static const accentSecondary = Color(0xFFCE6A2F);

  static const text = Colors.white;
  static const textDim = Color(0xFFB0B0B0);

  static const stroke = Color(0x22FFFFFF);
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.bg,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 28),
    bodyMedium: TextStyle(height: 1.3),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF31343D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.accentSecondary,
    thickness: 1,
  ),
);
