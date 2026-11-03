// 生成文・表示文が禁止語を含まないかを検査するゲート。Luckarise の OutputGate.kt を移植。
// 禁止語は平文で持たず SHA-256 ハッシュのみ保持する。純 Dart（package:crypto）。

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_models.dart';
import 'text_normalizer.dart';

class OutputGate {
  const OutputGate(this.latinHashes, this.cjkHashes);

  /// ハッシュが空のゲート（常に clean）。
  const OutputGate.empty()
      : latinHashes = const {},
        cjkHashes = const {};

  factory OutputGate.from(OutputGateData data) {
    final cjk = <int, Set<String>>{};
    for (final e in data.cjk) {
      cjk.putIfAbsent(e.len, () => <String>{}).add(e.sha256);
    }
    return OutputGate(data.latin.toSet(), cjk);
  }

  final Set<String> latinHashes;
  final Map<int, Set<String>> cjkHashes;

  bool isClean(String text) {
    if (cjkHashes.isNotEmpty) {
      final norm = cjkNorm(text);
      for (final entry in cjkHashes.entries) {
        final len = entry.key;
        if (len <= 0 || norm.length < len) continue;
        for (var i = 0; i <= norm.length - len; i++) {
          if (entry.value.contains(sha256Hex(norm.substring(i, i + len)))) return false;
        }
      }
    }
    if (latinHashes.isNotEmpty) {
      for (final candidate in latinCandidates(text)) {
        if (latinHashes.contains(sha256Hex(candidate))) return false;
      }
    }
    return true;
  }

  static String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

  static const int _katakanaStart = 0x30a1; // ァ
  static const int _katakanaEnd = 0x30f6; // ヶ
  static const int _katakanaToHiraganaShift = 0x60;
  static final Set<int> _stripChars =
      "・･・·'-‐－_. 。、,，!！?？「」『』()（）\"".codeUnits.toSet();

  /// CJK 照合用の正規化: normBase → カタカナをひらがなに → 区切り記号・空白を除く。
  static String cjkNorm(String s) {
    final normalized = TextNormalizer.normBase(s);
    final sb = StringBuffer();
    for (final c in normalized.codeUnits) {
      final mapped =
          (c >= _katakanaStart && c <= _katakanaEnd) ? c - _katakanaToHiraganaShift : c;
      if (_stripChars.contains(mapped) || TextNormalizer.isWhitespace(mapped)) continue;
      sb.writeCharCode(mapped);
    }
    return sb.toString();
  }

  /// ラテン文字の候補: 単語・隣接 2 語の連結・隣接 3 語の連結。
  static Set<String> latinCandidates(String text) {
    final sb = StringBuffer();
    for (final c in TextNormalizer.normBase(text).codeUnits) {
      if (c != 0x27 && c != 0x2d && c != 0x2e) sb.writeCharCode(c);
    }
    final tokens = sb.toString().split(RegExp('[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();
    final out = <String>{...tokens};
    for (var i = 0; i < tokens.length - 1; i++) {
      out.add(tokens[i] + tokens[i + 1]);
    }
    for (var i = 0; i < tokens.length - 2; i++) {
      out.add(tokens[i] + tokens[i + 1] + tokens[i + 2]);
    }
    return out;
  }
}
