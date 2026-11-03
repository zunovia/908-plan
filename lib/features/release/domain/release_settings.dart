// 手放す系の設定（Luckarise の Settings のうち Voxna で使うもの）。不変・copyWith。純 Dart。
// 言語・テーマは Voxna 既存の設定（settingsProvider）を使うので持たない。

import 'models.dart';
import 'own_tools.dart';

class ReleaseSettings {
  const ReleaseSettings({
    this.ttsEnabled = false,
    this.hapticsEnabled = true,
    this.goalCount = 27,
    this.loopSpeed = 'normal',
    this.breathIn = 4,
    this.breathHold = 4,
    this.breathOut = 8,
    this.quietStart = '22:00',
    this.quietEnd = '07:00',
    this.pauseUntil = 0,
    this.replayMode = ReplayMode.EVERY,
    this.disclaimerAcceptedAt,
    this.lastCrisisAt = 0,
    this.recentReplayIds = const [],
    this.recentCardIds = const [],
    this.recentReflectionIds = const [],
    this.customWords = const [],
    this.releaseTool = 'set',
    this.ownTools = const [],
    this.keepNotes = true,
    this.triggerCues = const [],
    this.triggerSentence = '',
    this.checkinMorningEnabled = false,
    this.checkinMorningTime = '07:30',
    this.checkinEveningEnabled = false,
    this.checkinEveningTime = '21:00',
    this.zeroDayEnabled = false,
    this.zeroDayTime = '20:00',
  });

  /// 読み上げ（既定オフ。手放しの画面の音のボタンで切り替える）。
  final bool ttsEnabled;
  final bool hapticsEnabled;

  /// 唱える回数の目標（既定 27）。
  final int goalCount;

  /// "off" / "slow" / "normal" / "fast"。
  final String loopSpeed;
  final int breathIn;
  final int breathHold;
  final int breathOut;

  /// 静音時間（"HH:mm"）。
  final String quietStart;
  final String quietEnd;

  /// 通知のお休み（epoch millis。0 = なし）。
  final int pauseUntil;
  final ReplayMode replayMode;

  /// 初回の説明（考え方・医療でない旨・窓口）に同意した時刻。null なら未同意（/release/intro を出す）。
  final int? disclaimerAcceptedAt;

  /// 最後に危機と判定した時刻（epoch millis。0 = なし）。24 時間は危機バナーを出す。
  final int lastCrisisAt;
  final List<String> recentReplayIds;
  final List<String> recentCardIds;
  final List<String> recentReflectionIds;

  /// ユーザーが書き換えた「手放す言葉」。空なら words.json の既定。
  final List<String> customWords;

  /// 手放しの画面で使うツール（ReleaseTools の id。"set" = いつもの組）。
  final String releaseTool;

  /// 自分でつくったツール（OwnTools）。
  final List<String> ownTools;

  /// 書いた内容を残す（false なら「残さない」が既定で ON）。
  final bool keepNotes;
  final List<TriggerCue> triggerCues;

  /// 本人の一文（例「寝る前に、ひと言手放す」）。通知のタイトルにも使う。最大 60 文字。
  final String triggerSentence;
  final bool checkinMorningEnabled;
  final String checkinMorningTime;
  final bool checkinEveningEnabled;
  final String checkinEveningTime;

  /// 「まだ 0 回の日」の通知。
  final bool zeroDayEnabled;
  final String zeroDayTime;

  LoopSpeed get loopSpeedValue => LoopSpeed.fromSetting(loopSpeed);
  bool get disclaimerAccepted => disclaimerAcceptedAt != null;

  ReleaseSettings copyWith({
    bool? ttsEnabled,
    bool? hapticsEnabled,
    int? goalCount,
    String? loopSpeed,
    int? breathIn,
    int? breathHold,
    int? breathOut,
    String? quietStart,
    String? quietEnd,
    int? pauseUntil,
    ReplayMode? replayMode,
    Object? disclaimerAcceptedAt = _keep,
    int? lastCrisisAt,
    List<String>? recentReplayIds,
    List<String>? recentCardIds,
    List<String>? recentReflectionIds,
    List<String>? customWords,
    String? releaseTool,
    List<String>? ownTools,
    bool? keepNotes,
    List<TriggerCue>? triggerCues,
    String? triggerSentence,
    bool? checkinMorningEnabled,
    String? checkinMorningTime,
    bool? checkinEveningEnabled,
    String? checkinEveningTime,
    bool? zeroDayEnabled,
    String? zeroDayTime,
  }) {
    return ReleaseSettings(
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      goalCount: goalCount ?? this.goalCount,
      loopSpeed: loopSpeed ?? this.loopSpeed,
      breathIn: breathIn ?? this.breathIn,
      breathHold: breathHold ?? this.breathHold,
      breathOut: breathOut ?? this.breathOut,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      replayMode: replayMode ?? this.replayMode,
      disclaimerAcceptedAt: identical(disclaimerAcceptedAt, _keep)
          ? this.disclaimerAcceptedAt
          : disclaimerAcceptedAt as int?,
      lastCrisisAt: lastCrisisAt ?? this.lastCrisisAt,
      recentReplayIds: recentReplayIds ?? this.recentReplayIds,
      recentCardIds: recentCardIds ?? this.recentCardIds,
      recentReflectionIds: recentReflectionIds ?? this.recentReflectionIds,
      customWords: customWords ?? this.customWords,
      releaseTool: releaseTool ?? this.releaseTool,
      ownTools: ownTools ?? this.ownTools,
      keepNotes: keepNotes ?? this.keepNotes,
      triggerCues: triggerCues ?? this.triggerCues,
      triggerSentence: triggerSentence ?? this.triggerSentence,
      checkinMorningEnabled: checkinMorningEnabled ?? this.checkinMorningEnabled,
      checkinMorningTime: checkinMorningTime ?? this.checkinMorningTime,
      checkinEveningEnabled: checkinEveningEnabled ?? this.checkinEveningEnabled,
      checkinEveningTime: checkinEveningTime ?? this.checkinEveningTime,
      zeroDayEnabled: zeroDayEnabled ?? this.zeroDayEnabled,
      zeroDayTime: zeroDayTime ?? this.zeroDayTime,
    );
  }

  static const Object _keep = Object();

  Map<String, dynamic> toMap() => {
        'ttsEnabled': ttsEnabled,
        'hapticsEnabled': hapticsEnabled,
        'goalCount': goalCount,
        'loopSpeed': loopSpeed,
        'breathIn': breathIn,
        'breathHold': breathHold,
        'breathOut': breathOut,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'pauseUntil': pauseUntil,
        'replayMode': replayMode.name,
        'disclaimerAcceptedAt': disclaimerAcceptedAt,
        'lastCrisisAt': lastCrisisAt,
        'recentReplayIds': RecentIds.encode(recentReplayIds),
        'recentCardIds': RecentIds.encode(recentCardIds),
        'recentReflectionIds': RecentIds.encode(recentReflectionIds),
        'customWords': CustomWords.encode(customWords),
        'releaseTool': releaseTool,
        'ownTools': OwnTools.encode(ownTools),
        'keepNotes': keepNotes,
        'triggerCues': TriggerCue.encode(triggerCues),
        'triggerSentence': triggerSentence,
        'checkinMorningEnabled': checkinMorningEnabled,
        'checkinMorningTime': checkinMorningTime,
        'checkinEveningEnabled': checkinEveningEnabled,
        'checkinEveningTime': checkinEveningTime,
        'zeroDayEnabled': zeroDayEnabled,
        'zeroDayTime': zeroDayTime,
      };

  /// 保存値から復元。欠けた・型が違う値は既定値。
  factory ReleaseSettings.fromMap(Map? raw) {
    const d = ReleaseSettings();
    if (raw == null) return d;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    bool b(String k, bool def) => m[k] is bool ? m[k] as bool : def;
    int i(String k, int def) => m[k] is num ? (m[k] as num).toInt() : def;
    String s(String k, String def) => m[k] is String ? m[k] as String : def;
    String? sn(String k) => m[k] is String ? m[k] as String : null;
    return ReleaseSettings(
      ttsEnabled: b('ttsEnabled', d.ttsEnabled),
      hapticsEnabled: b('hapticsEnabled', d.hapticsEnabled),
      goalCount: i('goalCount', d.goalCount),
      loopSpeed: s('loopSpeed', d.loopSpeed),
      breathIn: i('breathIn', d.breathIn),
      breathHold: i('breathHold', d.breathHold),
      breathOut: i('breathOut', d.breathOut),
      quietStart: s('quietStart', d.quietStart),
      quietEnd: s('quietEnd', d.quietEnd),
      pauseUntil: i('pauseUntil', d.pauseUntil),
      replayMode: enumByName(ReplayMode.values, sn('replayMode')) ?? d.replayMode,
      disclaimerAcceptedAt: m['disclaimerAcceptedAt'] is num
          ? (m['disclaimerAcceptedAt'] as num).toInt()
          : null,
      lastCrisisAt: i('lastCrisisAt', d.lastCrisisAt),
      recentReplayIds: RecentIds.decode(sn('recentReplayIds')),
      recentCardIds: RecentIds.decode(sn('recentCardIds')),
      recentReflectionIds: RecentIds.decode(sn('recentReflectionIds')),
      customWords: CustomWords.decode(sn('customWords')),
      releaseTool: s('releaseTool', d.releaseTool),
      ownTools: OwnTools.decode(sn('ownTools')),
      keepNotes: b('keepNotes', d.keepNotes),
      triggerCues: TriggerCue.decode(sn('triggerCues')),
      triggerSentence: s('triggerSentence', d.triggerSentence),
      checkinMorningEnabled: b('checkinMorningEnabled', d.checkinMorningEnabled),
      checkinMorningTime: s('checkinMorningTime', d.checkinMorningTime),
      checkinEveningEnabled: b('checkinEveningEnabled', d.checkinEveningEnabled),
      checkinEveningTime: s('checkinEveningTime', d.checkinEveningTime),
      zeroDayEnabled: b('zeroDayEnabled', d.zeroDayEnabled),
      zeroDayTime: s('zeroDayTime', d.zeroDayTime),
    );
  }
}
