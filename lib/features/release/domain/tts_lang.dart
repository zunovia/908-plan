// 読み上げ言語の決め方。Luckarise の CleaningViewModel.ttsLangFor を移植。純 Dart。
// ユーザーが書いた「手放す言葉」は UI 言語と一致しないことがあるため、語の文字種で決める。

import 'models.dart';

/// かな・漢字を含めば ja、ASCII だけなら en（UI が es / pt ならその言語）、それ以外は UI 言語。
AppLang ttsLangFor(String word, AppLang uiLang) {
  if (word.trim().isEmpty) return uiLang;
  final units = word.codeUnits;
  if (units.any((c) => (c >= 0x3040 && c <= 0x30ff) || (c >= 0x4e00 && c <= 0x9fff))) {
    return AppLang.ja;
  }
  if (units.every((c) => c < 0x80)) {
    return (uiLang == AppLang.es || uiLang == AppLang.pt) ? uiLang : AppLang.en;
  }
  return uiLang;
}

/// flutter_tts の setLanguage に渡す言語タグ（Luckarise の Locale と同じ: ja / en-US / es-ES、pt は pt-BR）。
String ttsLocaleTag(AppLang lang) {
  switch (lang) {
    case AppLang.ja:
      return 'ja-JP';
    case AppLang.en:
      return 'en-US';
    case AppLang.es:
      return 'es-ES';
    case AppLang.pt:
      return 'pt-BR';
  }
}
