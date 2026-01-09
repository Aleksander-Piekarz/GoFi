import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors
  static const bg = Color(0xFFF8F9FA);
  static const bgAlt = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F3F5);

  static const accent = Color(0xFF4F46E5);  // Indigo - nowoczesny akcent
  static const accentSecondary = Color(0xFF7C3AED);  // Purple
  static const accentLight = Color(0xFFEEF2FF);

  static const text = Color(0xFF1F2937);
  static const textDim = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const stroke = Color(0xFFE5E7EB);
  static const divider = Color(0xFFE5E7EB);

  // Status colors
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Gradient colors
  static const gradientStart = Color(0xFF4F46E5);
  static const gradientEnd = Color(0xFF7C3AED);
}

final appTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.light(
    primary: AppColors.accent,
    secondary: AppColors.accentSecondary,
    surface: AppColors.surface,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onPrimary: Colors.white,
    onSurface: AppColors.text,
    outline: AppColors.textDim,
    error: AppColors.error,
    primaryContainer: AppColors.accentLight,
    onPrimaryContainer: AppColors.accent,
    secondaryContainer: AppColors.successLight,
    onSecondaryContainer: AppColors.success,
    tertiary: AppColors.accentSecondary,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bgAlt,
    foregroundColor: AppColors.text,
    elevation: 0,
    scrolledUnderElevation: 1,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardTheme(
    color: AppColors.bgAlt,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.stroke, width: 1),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 28,
      color: AppColors.text,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20,
      color: AppColors.text,
    ),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: AppColors.text,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: AppColors.text,
    ),
    bodyMedium: TextStyle(
      height: 1.5,
      color: AppColors.text,
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: AppColors.textDim,
      letterSpacing: 0.5,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accent,
      side: const BorderSide(color: AppColors.stroke, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accent,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.stroke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: const TextStyle(color: AppColors.textMuted),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.divider,
    thickness: 1,
    space: 1,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.bgAlt,
    indicatorColor: AppColors.accentLight,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        );
      }
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textDim,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.accent, size: 24);
      }
      return const IconThemeData(color: AppColors.textDim, size: 24);
    }),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.text,
    contentTextStyle: const TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  dialogTheme: DialogTheme(
    backgroundColor: AppColors.bgAlt,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.bgAlt,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceVariant,
    selectedColor: AppColors.accentLight,
    labelStyle: const TextStyle(color: AppColors.text, fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    side: BorderSide.none,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.accent,
    linearTrackColor: AppColors.surfaceVariant,
    circularTrackColor: AppColors.surfaceVariant,
  ),
);
