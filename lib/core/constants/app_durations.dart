abstract final class AppDurations {
  /// ページ遷移
  static const Duration pageTransition = Duration(milliseconds: 300);

  /// モーダル表示
  static const Duration modal = Duration(milliseconds: 350);

  /// テキストフェードイン（1文字あたり）
  static const Duration charFadeIn = Duration(milliseconds: 40);

  /// ハイライトカラーフェードイン
  static const Duration highlightFade = Duration(milliseconds: 600);

  /// 録音ボタンパルス（1サイクル）
  static const Duration recordingPulse = Duration(milliseconds: 2000);

  /// 呼吸ドット拡縮（1サイクル）
  static const Duration breathingDot = Duration(milliseconds: 3000);

  /// インサイトテキスト表示
  static const Duration insightFadeIn = Duration(milliseconds: 400);

  /// 静かな一言フェードイン
  static const Duration quietWordIn = Duration(milliseconds: 800);

  /// 静かな一言フェードアウト
  static const Duration quietWordOut = Duration(milliseconds: 1200);

  /// グラフ描画
  static const Duration chartDraw = Duration(milliseconds: 800);

  /// 問いかけカードスライドイン
  static const Duration cardSlideIn = Duration(milliseconds: 500);

  /// イントロ全体
  static const Duration introFull = Duration(milliseconds: 15000);

  /// 2回目以降のスプラッシュ
  static const Duration splashShort = Duration(milliseconds: 1500);
}
