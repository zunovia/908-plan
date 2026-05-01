import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkSurfacePrimary,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.darkSurfacePrimary,
          surfaceContainerHighest: AppColors.darkSurfaceSecondary,
          primary: AppColors.darkAccentWarm,
          onPrimary: AppColors.darkSurfacePrimary,
          secondary: AppColors.darkAccentCool,
          tertiary: AppColors.darkAccentCalm,
          onSurface: AppColors.darkTextPrimary,
          outline: AppColors.darkBorder,
        ),
        textTheme: TextTheme(
          headlineMedium: AppTypography.heading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
          bodyLarge: AppTypography.body.copyWith(
            color: AppColors.darkTextPrimary,
          ),
          bodyMedium: AppTypography.caption.copyWith(
            color: AppColors.darkTextSecondary,
          ),
          displaySmall: AppTypography.data.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.darkSurfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurfacePrimary,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurfacePrimary,
          selectedItemColor: AppColors.darkAccentWarm,
          unselectedItemColor: AppColors.darkTextMuted,
        ),
        dividerColor: AppColors.darkBorder,
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightSurfacePrimary,
        colorScheme: const ColorScheme.light(
          surface: AppColors.lightSurfacePrimary,
          surfaceContainerHighest: AppColors.lightSurfaceSecondary,
          primary: AppColors.lightAccentWarm,
          onPrimary: AppColors.lightSurfacePrimary,
          secondary: AppColors.lightAccentCool,
          tertiary: AppColors.lightAccentCalm,
          onSurface: AppColors.lightTextPrimary,
          outline: AppColors.lightBorder,
        ),
        textTheme: TextTheme(
          headlineMedium: AppTypography.heading.copyWith(
            color: AppColors.lightTextPrimary,
          ),
          bodyLarge: AppTypography.body.copyWith(
            color: AppColors.lightTextPrimary,
          ),
          bodyMedium: AppTypography.caption.copyWith(
            color: AppColors.lightTextSecondary,
          ),
          displaySmall: AppTypography.data.copyWith(
            color: AppColors.lightTextPrimary,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.lightSurfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightSurfacePrimary,
          foregroundColor: AppColors.lightTextPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightSurfacePrimary,
          selectedItemColor: AppColors.lightAccentWarm,
          unselectedItemColor: AppColors.lightTextMuted,
        ),
        dividerColor: AppColors.lightBorder,
      );
}
