import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Tema global de la aplicación: Negro Puro OLED con tipografía Apple iOS
class AppTheme {
  static ThemeData get darkOledTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.pureBlackOled,
      primaryColor: AppColors.textWhite,
      canvasColor: AppColors.pureBlackOled,
      cardColor: AppColors.cardDark,
      dialogBackgroundColor: AppColors.surfaceDark,
      dividerColor: AppColors.borderDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textWhite,
        secondary: AppColors.chordAmber,
        surface: AppColors.surfaceDark,
      ),
      textTheme: TextTheme(
        headlineMedium: AppTypography.sfProHeadline(),
        bodyLarge: AppTypography.sfProLyricStyle(fontSize: 18),
        bodyMedium: AppTypography.sfProCaption(),
      ),
    );
  }
}
