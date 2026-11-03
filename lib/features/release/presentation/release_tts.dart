// 手放しシーンの読み上げ（flutter_tts の小さな包み）。既定オフで、音のボタンを押したときだけ使う。
// 端末に読み上げの音声データが無い言語では何も話さず [languageMissing] を true にする（例外は外に出さない）。

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/models.dart';
import '../domain/tts_lang.dart';

class ReleaseTts {
  ReleaseTts({FlutterTts Function()? create}) : _create = create ?? FlutterTts.new;

  final FlutterTts Function() _create;
  FlutterTts? _tts;
  String? _languageTag;

  /// 読み上げ用の音声が端末に無い（または読み上げが使えない）。
  final ValueNotifier<bool> languageMissing = ValueNotifier<bool>(false);

  /// [text] を [lang] の声で読む（前の読み上げは止める）。
  Future<void> speak(String text, AppLang lang) async {
    if (text.trim().isEmpty) return;
    try {
      final tts = _tts ??= _create();
      final tag = ttsLocaleTag(lang);
      if (tag != _languageTag) {
        final result = await tts.setLanguage(tag);
        if (result == 0 || result == false) {
          _languageTag = null;
          languageMissing.value = true;
          return;
        }
        _languageTag = tag;
        languageMissing.value = false;
      }
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // 読み上げエンジンが無い端末など。音が出ないだけなので画面は続ける。
      languageMissing.value = true;
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // 止められなくても続ける。
    }
  }

  void dispose() {
    stop();
    languageMissing.dispose();
  }
}
