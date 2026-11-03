// 手放す画面の共通部品: ルートのパス、シーンへの引数、表示用の文言の対応、画面だけで使うプロバイダー。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/storage_providers.dart';
import '../domain/models.dart';
import '../domain/release_tools.dart';
import '../domain/voice_tendency.dart';
import 'release_tts.dart';

/// 手放す機能のルート。タブ `/release` の下に全画面のルートを置く（ルートの Navigator に積む）。
abstract final class ReleasePaths {
  static const String home = '/release';
  static const String intro = '/release/intro';
  static const String write = '/release/write';
  static const String scene = '/release/scene';
  static const String quick = '/release/quick';
  static const String done = '/release/done';
  static const String records = '/release/records';
  static const String chat = '/release/chat';
  static const String crisis = '/release/crisis';
  static const String breath = '/release/breath';

  /// 書く画面。[voice] は録音 id、[source] は「もう一度手放す」の元の記録、[pending] は「あとで手放す」。
  static String writeWith({String? voice, String? source, String? pending}) {
    final q = <String, String>{
      if (voice != null) 'voice': voice,
      if (source != null) 'source': source,
      if (pending != null) 'pending': pending,
    };
    return Uri(path: write, queryParameters: q.isEmpty ? null : q).toString();
  }

  static String doneFor(String sessionId) =>
      Uri(path: done, queryParameters: {'session': sessionId}).toString();

  static String crisisWith({bool abuse = false}) => abuse ? '$crisis?abuse=1' : crisis;

  static String breathWith({String? cardId}) =>
      cardId == null ? breath : Uri(path: breath, queryParameters: {'card': cardId}).toString();
}

/// 手放しシーンへ渡す内容（go_router の extra。クエリでも mode/card/emotion/replay/quick を受ける）。
class ReleaseSceneArgs {
  const ReleaseSceneArgs({
    this.mode = ReleaseMode.WORDS4,
    this.cardId,
    this.emotion,
    this.replayId,
    this.trigger = SessionTrigger.MANUAL,
    this.note,
    this.tags = const [],
    this.scene,
    this.keep = true,
    this.sourceSessionId,
    this.pendingEventId,
    this.quick = false,
    this.meltText,
    this.voiceRecordingId,
    this.abuseContext = false,
    this.softCrisis = false,
  });

  /// 15 秒のひと言（今日の一枚・通知）。
  const ReleaseSceneArgs.quick()
      : mode = ReleaseMode.WORDS1,
        cardId = null,
        emotion = null,
        replayId = null,
        trigger = SessionTrigger.QUICK,
        note = null,
        tags = const [],
        scene = null,
        keep = true,
        sourceSessionId = null,
        pendingEventId = null,
        quick = true,
        meltText = null,
        voiceRecordingId = null,
        abuseContext = false,
        softCrisis = false;

  factory ReleaseSceneArgs.fromQuery(Map<String, String> q) => ReleaseSceneArgs(
        mode: ReleaseMode.fromName(q['mode']),
        cardId: q['card'],
        emotion: enumByName(EmotionTag.values, q['emotion']),
        replayId: q['replay'],
        quick: q['quick'] == '1',
        trigger: q['quick'] == '1' ? SessionTrigger.QUICK : SessionTrigger.MANUAL,
      );

  final ReleaseMode mode;
  final String? cardId;
  final EmotionTag? emotion;
  final String? replayId;
  final SessionTrigger trigger;

  /// 書いた本文（「残さない」なら保存しない）。
  final String? note;
  final List<String> tags;
  final String? scene;
  final bool keep;
  final String? sourceSessionId;
  final String? pendingEventId;
  final bool quick;

  /// 溶ける演出に出す文字。
  final String? meltText;
  final String? voiceRecordingId;

  /// 虐待・ハラスメントの文脈（再生リマインドを出さない）。
  final bool abuseContext;

  /// 書いた内容が柔らかい危機（相談窓口のバナーを出して続ける）。
  final bool softCrisis;
}

// ---- 表示用の文言 ----

/// 声の傾向タグ（"voice:..."）の表示名。その他のタグはそのまま。
String relTagLabel(AppLocalizations l10n, String tag) {
  switch (tag) {
    case VoiceTendency.lowEnergy:
      return l10n.rel_vx_voice_low_energy;
    case 'voice:high_energy':
      return l10n.rel_vx_voice_high_energy;
    case VoiceTendency.fastTempo:
      return l10n.rel_vx_voice_fast_tempo;
    case 'voice:slow_tempo':
      return l10n.rel_vx_voice_slow_tempo;
    case VoiceTendency.narrowRange:
      return l10n.rel_vx_voice_narrow_range;
    case VoiceTendency.lowClarity:
      return l10n.rel_vx_voice_low_clarity;
    case VoiceTendency.steady:
      return l10n.rel_vx_voice_steady;
    default:
      return tag;
  }
}

bool relIsVoiceTag(String tag) => tag.startsWith('voice:');

/// 記憶チップの既定（6 つ）。
List<String> relMemoryDefaults(AppLocalizations l10n) => [
      l10n.rel_memory_label_defaults_0,
      l10n.rel_memory_label_defaults_1,
      l10n.rel_memory_label_defaults_2,
      l10n.rel_memory_label_defaults_3,
      l10n.rel_memory_label_defaults_4,
      l10n.rel_memory_label_defaults_5,
    ];

/// 場面チップの既定（5 つ）。
List<String> relSceneDefaults(AppLocalizations l10n) => [
      l10n.rel_scene_defaults_0,
      l10n.rel_scene_defaults_1,
      l10n.rel_scene_defaults_2,
      l10n.rel_scene_defaults_3,
      l10n.rel_scene_defaults_4,
    ];

/// 対話の感情チップ（Luckarise と同じ 7 語）。
List<(EmotionTag, String)> relEmotionChips(AppLocalizations l10n) => [
      (EmotionTag.ANXIETY, l10n.rel_emotion_anxiety),
      (EmotionTag.ANGER, l10n.rel_emotion_anger),
      (EmotionTag.SADNESS, l10n.rel_emotion_sadness),
      (EmotionTag.LONELINESS, l10n.rel_emotion_loneliness),
      (EmotionTag.FEAR, l10n.rel_emotion_fear),
      (EmotionTag.FATIGUE, l10n.rel_emotion_fatigue),
      (EmotionTag.CONFUSION, l10n.rel_emotion_confusion),
    ];

// ---- 画面だけで使うプロバイダー ----

/// 読み上げ（既定オフ。テストでは差し替える）。
final releaseTtsProvider = Provider<ReleaseTts>((ref) {
  final tts = ReleaseTts();
  ref.onDispose(tts.dispose);
  return tts;
});

/// 録音 [recordingId] の声の傾向タグ（"voice:..."。ベースラインが足りなければ空）。
final releaseVoiceTagsProvider = Provider.family<List<String>, String>((ref, recordingId) {
  try {
    final all = ref.watch(localRecordingRepositoryProvider).getRecordings();
    final current = all.where((r) => r.id == recordingId).firstOrNull;
    if (current == null) return const [];
    return VoiceTendency.tagsForRecording(current, all);
  } catch (_) {
    // 録音の箱が開けない等。下書きのタグが無いだけなので続ける。
    return const [];
  }
});

// ---- 小さな共通処理 ----

/// 触覚（端末が対応しなくても失敗させない）。
void relHaptic({bool strong = false}) {
  final f = strong ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
  f.catchError((Object _) {});
}

/// 戻る: 積まれていれば戻り、無ければ手放すタブへ。
void relBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(ReleasePaths.home);
  }
}

/// "M/d HH:mm"。
String relTimeLabel(int epochMillis) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochMillis);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
}
