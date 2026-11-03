// 手放す画面の文字と色。Voxna のトークン（AppTypography / AppColors）をそのまま使う。
// テストでは google_fonts の読み込み（ネットワーク）を避けるため [RelStyles.plainFonts] を true にする。

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

abstract final class RelStyles {
  /// true なら google_fonts を使わず同じ大きさ・行間の素の TextStyle を返す（ウィジェットテスト用）。
  @visibleForTesting
  static bool plainFonts = false;

  /// 見出し 20sp。
  static TextStyle get heading => plainFonts
      ? const TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w500)
      : AppTypography.heading;

  /// 本文 15sp。
  static TextStyle get body =>
      plainFonts ? const TextStyle(fontSize: 15, height: 1.6) : AppTypography.body;

  /// 補助 13sp。
  static TextStyle get caption =>
      plainFonts ? const TextStyle(fontSize: 13, height: 1.5) : AppTypography.caption;

  /// 数値 28sp。
  static TextStyle get data => plainFonts
      ? const TextStyle(fontSize: 28, height: 1.3, fontWeight: FontWeight.w300)
      : AppTypography.data;

  /// 考え方・語りかけ（明朝）18sp。
  static TextStyle get philosophy =>
      plainFonts ? const TextStyle(fontSize: 18, height: 1.8) : AppTypography.philosophy;

  /// 短い一文（明朝）16sp。
  static TextStyle get line =>
      plainFonts ? const TextStyle(fontSize: 16, height: 1.8) : AppTypography.miniInsight;
}

/// 画面の明暗に合わせた Voxna の色。
class RelPalette {
  const RelPalette({
    required this.text,
    required this.subText,
    required this.muted,
    required this.accent,
    required this.ice,
    required this.calm,
    required this.surface,
    required this.surfaceSecondary,
    required this.border,
  });

  factory RelPalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const RelPalette(
            text: AppColors.darkTextPrimary,
            subText: AppColors.darkTextSecondary,
            muted: AppColors.darkTextMuted,
            accent: AppColors.darkAccentWarm,
            ice: AppColors.darkAccentCool,
            calm: AppColors.darkAccentCalm,
            surface: AppColors.darkSurfacePrimary,
            surfaceSecondary: AppColors.darkSurfaceSecondary,
            border: AppColors.darkBorder,
          )
        : const RelPalette(
            text: AppColors.lightTextPrimary,
            subText: AppColors.lightTextSecondary,
            muted: AppColors.lightTextMuted,
            accent: AppColors.lightAccentWarm,
            ice: AppColors.lightAccentCool,
            calm: AppColors.lightAccentCalm,
            surface: AppColors.lightSurfacePrimary,
            surfaceSecondary: AppColors.lightSurfaceSecondary,
            border: AppColors.lightBorder,
          );
  }

  final Color text;
  final Color subText;
  final Color muted;

  /// 主色（Voxna の温かいアクセント）。
  final Color accent;

  /// 氷の青（Voxna の涼しいアクセント）。溶ける演出・呼吸リング。
  final Color ice;
  final Color calm;
  final Color surface;
  final Color surfaceSecondary;
  final Color border;
}

/// 端末の「アニメーションを減らす」設定。
bool relReduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
