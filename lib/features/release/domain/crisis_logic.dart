// 相談窓口画面の国選択・並び順。Luckarise の feature/crisis/CrisisLogic.kt を移植。純 Dart。
// Flutter からは SIM・ネットワークの国が読めないため、呼び出し側が集めた文字列（空でよい）を渡す。

import 'content_models.dart';

/// 相談窓口のデータが無い・一致しない場合の国コード。
const String otherCountryCode = 'OTHER';

class CrisisLogic {
  const CrisisLogic._();

  /// 危機バナーを出す期間（最後の危機判定から 24 時間）。
  static const int bannerWindowMillis = 24 * 60 * 60 * 1000;

  /// 端末の国コードを窓口データの表記に正規化する（"UK" → "GB"）。
  static String normalizeCountryCode(String raw) {
    final up = raw.toUpperCase();
    return up == 'UK' ? 'GB' : up;
  }

  /// 1 つの国コードから、使える国コードの中で初期選択すべきもの（無ければ OTHER）。
  static String resolveInitialCountryCodeFrom(String rawCountryCode, List<String> availableCodes) {
    final normalized = normalizeCountryCode(rawCountryCode);
    return availableCodes.contains(normalized) ? normalized : otherCountryCode;
  }

  /// 初期国を複数の候補から優先順に決める:
  /// 1. [systemCountry]（端末のシステムロケールの国。例 PlatformDispatcher.instance.locale.countryCode）
  /// 2. [simCountry]、空なら [networkCountry]（Flutter では通常取れないので空文字を渡す）
  /// 3. [defaultCountry]（その他の既定ロケールの国）
  /// 4. すべて空で [appLang] が "ja" なら JP と推定（en 等は推定しない）
  /// 5. それでも決まらない・[availableCodes] に無ければ OTHER
  static String resolveInitialCountryCode({
    String systemCountry = '',
    String simCountry = '',
    String networkCountry = '',
    String defaultCountry = '',
    required String appLang,
    required List<String> availableCodes,
  }) {
    String? raw;
    if (systemCountry.trim().isNotEmpty) {
      raw = systemCountry;
    } else if (simCountry.trim().isNotEmpty) {
      raw = simCountry;
    } else if (networkCountry.trim().isNotEmpty) {
      raw = networkCountry;
    } else if (defaultCountry.trim().isNotEmpty) {
      raw = defaultCountry;
    } else if (appLang.toLowerCase() == 'ja') {
      raw = 'JP';
    }
    if (raw == null || raw.trim().isEmpty) return otherCountryCode;
    return resolveInitialCountryCodeFrom(raw, availableCodes);
  }

  /// abuse=true のときは kind=="ABUSE" の行を先頭に（元の順序は保つ安定な並べ替え）。
  static List<HelplineEntry> sortedLines(List<HelplineEntry> lines, {required bool abuse}) {
    if (!abuse) return List.of(lines);
    return [
      ...lines.where((l) => l.kind == 'ABUSE'),
      ...lines.where((l) => l.kind != 'ABUSE'),
    ];
  }

  /// 国コードの表示ラベル（"GB" は "UK"）。
  static String displayLabel(String countryCode) => countryCode == 'GB' ? 'UK' : countryCode;

  /// 危機バナーを出すか（最後の危機判定から 24 時間以内）。[lastCrisisAt] が 0 なら出さない。
  static bool isBannerVisible(int lastCrisisAt, int nowMillis) =>
      lastCrisisAt > 0 && nowMillis - lastCrisisAt < bannerWindowMillis;
}
