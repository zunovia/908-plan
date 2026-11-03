// 自分でつくった「ツール」の正規化と保存形式。Luckarise 0.1.6 の data/prefs/OwnTools.kt を移植。純 Dart。

/// 自分でつくった「ツール」（例「パソコンの Delete キーを押す」）。1 つ 1 行、最大 10 個・1 つ 40 文字。
class OwnTools {
  const OwnTools._();

  static const int maxTools = 10;
  static const int maxLength = 40;

  /// [maxLength] で切る。絵文字などのサロゲートペアを途中で割らない。
  static String clip(String text) {
    var t = text.length <= maxLength ? text : text.substring(0, maxLength);
    if (t.isNotEmpty) {
      final last = t.codeUnitAt(t.length - 1);
      if (last >= 0xd800 && last <= 0xdbff) t = t.substring(0, t.length - 1);
    }
    return t;
  }

  static String normalizeOne(String text) => clip(text.replaceAll(RegExp(r'\s+'), ' ').trim()).trim();

  static List<String> normalize(List<String> tools) {
    final out = <String>[];
    for (final t in tools) {
      final n = normalizeOne(t);
      if (n.isEmpty || out.contains(n)) continue;
      out.add(n);
      if (out.length >= maxTools) break;
    }
    return out;
  }

  static String encode(List<String> tools) => normalize(tools).join('\n');

  static List<String> decode(String? raw) =>
      (raw == null || raw.trim().isEmpty) ? const [] : normalize(raw.split('\n'));
}
