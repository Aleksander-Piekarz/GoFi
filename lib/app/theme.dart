import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === KOLORY ===
class AppColors {
  static const bg = Color(0xFF121212);
  static const bgAlt = Color(0xFF1E1E1E);

  static const accent = Color(0xFFFD605B);
  static const accentSecondary = Color(0xFFCE6A2F);

  static const text = Colors.white;
  static const textDim = Color(0xFFB0B0B0);

  static const stroke = Color(0x22FFFFFF);
  
  // Light theme colors
  static const lightBg = Color(0xFFF5F5F5);
  static const lightBgAlt = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1A1A1A);
  static const lightTextDim = Color(0xFF6B6B6B);
}

// === THEME PROVIDER ===
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }
  
  static const String _key = 'theme_mode';
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') {
      state = ThemeMode.light;
    } else if (saved == 'system') {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.dark;
    }
  }
  
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
  
  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}

// === DARK THEME ===
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.bg,
    surfaceContainerHighest: AppColors.bgAlt,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bg,
    foregroundColor: Colors.white,
  ),
  cardTheme: CardTheme(
    color: AppColors.bgAlt,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, color: Colors.white),
    bodyMedium: TextStyle(height: 1.3, color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.accentSecondary,
    thickness: 1,
  ),
);

// === LIGHT THEME ===
final lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBg,
  colorScheme: const ColorScheme.light(
    primary: AppColors.accent,
    surface: AppColors.lightBg,
    surfaceContainerHighest: AppColors.lightBgAlt,
    onSurface: AppColors.lightText,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBgAlt,
    foregroundColor: AppColors.lightText,
    elevation: 0,
  ),
  cardTheme: CardTheme(
    color: AppColors.lightBgAlt,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, color: AppColors.lightText),
    bodyMedium: TextStyle(height: 1.3, color: AppColors.lightText),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.lightText,
      side: const BorderSide(color: Colors.black26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Colors.black12,
    thickness: 1,
  ),
);

// Legacy - dla kompatybilności
final appTheme = darkTheme;
