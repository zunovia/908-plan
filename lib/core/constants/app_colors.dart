import 'package:flutter/material.dart';

abstract final class AppColors {
  // Dark mode
  static const darkSurfacePrimary = Color(0xFF0A0A0F);
  static const darkSurfaceSecondary = Color(0xFF12121A);
  static const darkSurfaceElevated = Color(0xFF1A1A24);
  static const darkTextPrimary = Color(0xFFE8E6E0);
  static const darkTextSecondary = Color(0xFF8A8A8A);
  static const darkTextMuted = Color(0xFF4A4A4A);
  static const darkAccentWarm = Color(0xFFC4956A);
  static const darkAccentCool = Color(0xFF6A8EC4);
  static const darkAccentCalm = Color(0xFF6AC49A);
  static const darkBorder = Color(0xFF1F1F2A);
  static const darkRecordingPulse = Color(0x4DC4956A); // 30% alpha

  // Light mode
  static const lightSurfacePrimary = Color(0xFFFAFAF8);
  static const lightSurfaceSecondary = Color(0xFFF2F2EE);
  static const lightSurfaceElevated = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF1A1A1F);
  static const lightTextSecondary = Color(0xFF6B6B6B);
  static const lightTextMuted = Color(0xFFA0A0A0);
  static const lightAccentWarm = Color(0xFFB8845A);
  static const lightAccentCool = Color(0xFF5A7EB8);
  static const lightAccentCalm = Color(0xFF5AB88A);
  static const lightBorder = Color(0xFFE5E5E0);
  static const lightRecordingPulse = Color(0x33B8845A); // 20% alpha
}
