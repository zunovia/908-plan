import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  /// 理念・問いかけ — Noto Serif JP Regular 18sp, 行間1.8
  static TextStyle get philosophy => GoogleFonts.notoSerifJp(
        fontWeight: FontWeight.w400,
        fontSize: 18,
        height: 1.8,
      );

  /// 見出し — Noto Sans JP Medium 20sp, 行間1.5
  static TextStyle get heading => GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w500,
        fontSize: 20,
        height: 1.5,
      );

  /// 本文 — Noto Sans JP Regular 15sp, 行間1.6
  static TextStyle get body => GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 1.6,
      );

  /// 補助 — Noto Sans JP Regular 13sp, 行間1.5
  static TextStyle get caption => GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w400,
        fontSize: 13,
        height: 1.5,
      );

  /// 数値・データ — Noto Sans JP Light 28sp, 行間1.3
  static TextStyle get data => GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w300,
        fontSize: 28,
        height: 1.3,
      );

  /// ミニインサイト — Noto Serif JP Regular 16sp, 行間1.8
  static TextStyle get miniInsight => GoogleFonts.notoSerifJp(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.8,
      );

  /// スプラッシュ中にフォントをプリロード
  static Future<void> preload() => GoogleFonts.pendingFonts([
        philosophy,
        heading,
        body,
        caption,
        data,
        miniInsight,
      ]);
}
