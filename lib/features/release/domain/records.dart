// 端末内に保存する手放しの記録（Hive の Box<Map> に JSON Map で入れる）。
// Luckarise の data/db/Entities.kt（SessionEntity / DialogueTurnEntity / PendingEventEntity）に対応。純 Dart。

import 'models.dart';

Map<String, dynamic> _m(Map raw) => raw.map((k, v) => MapEntry(k.toString(), v));
int? _i(Object? v) => v is num ? v.toInt() : null;
String? _s(Object? v) => v is String ? v : null;

/// 実践セッション 1 件。危機時は [crisis]=true で本文を保存せず記録のみ残す。
class ReleaseSession {
  const ReleaseSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.kind,
    this.count = 0,
    this.moodBefore,
    this.moodAfter,
    this.emotion,
    this.cardId,
    this.memoryLabel,
    this.crisis = false,
    this.trigger = SessionTrigger.MANUAL,
    this.occurredAt,
    this.note,
    this.memoryTags = const [],
    this.scene,
    this.sourceSessionId,
    this.releaseCount = 1,
    this.lastReleasedAt,
    this.voiceRecordingId,
  });

  final String id;
  final int startedAt;
  final int? endedAt;
  final SessionKind kind;

  /// 唱えた回数（0 なら未完了）。
  final int count;
  final int? moodBefore;
  final int? moodAfter;
  final EmotionTag? emotion;
  final String? cardId;

  /// 代表の記憶チップ（memoryTags の先頭。よく手放した記憶の集計に使う）。
  final String? memoryLabel;
  final bool crisis;
  final SessionTrigger trigger;

  /// 出来事が起きた時刻（「あとで手放す」から入った場合）。
  final int? occurredAt;

  /// 書いた本文。「残さない」で手放した回は null。
  final String? note;

  /// 記憶チップ（声の傾向タグ "voice:..." を含むことがある）。
  final List<String> memoryTags;

  /// 場面チップ（会う前 など）。
  final String? scene;

  /// 「もう一度手放す」で元になった記録の id。null なら新規。
  final String? sourceSessionId;

  /// 元の記録として、これまでに手放した回数（もう一度手放すたびに +1）。
  final int releaseCount;

  /// 最後に手放した時刻（記録一覧の並び替え用）。
  final int? lastReleasedAt;

  /// Voxna の録音（RecordingModel.id）と紐づける場合。
  final String? voiceRecordingId;

  /// 完了した実践（危機を除き、回数 > 0、終了済み）。
  bool get isCompleted => !crisis && count > 0 && endedAt != null;

  /// 記録一覧に出るもの（完了・本文あり・「もう一度」の子ではない）。
  bool get isRecord => isCompleted && note != null && sourceSessionId == null;

  /// 並び替えの時刻（最後に手放した時刻、無ければ終了時刻）。
  int get sortAt => lastReleasedAt ?? endedAt ?? startedAt;

  /// 記憶チップを正規化する（前後の空白・空・重複を除く）。
  static List<String> normalizeTags(List<String> tags) {
    final out = <String>[];
    for (final t in tags) {
      final s = t.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }
    return out;
  }

  ReleaseSession copyWith({
    int? endedAt,
    int? count,
    Object? moodAfter = _keep,
    Object? memoryLabel = _keep,
    int? releaseCount,
    int? lastReleasedAt,
  }) {
    return ReleaseSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      kind: kind,
      count: count ?? this.count,
      moodBefore: moodBefore,
      moodAfter: identical(moodAfter, _keep) ? this.moodAfter : moodAfter as int?,
      emotion: emotion,
      cardId: cardId,
      memoryLabel: identical(memoryLabel, _keep) ? this.memoryLabel : memoryLabel as String?,
      crisis: crisis,
      trigger: trigger,
      occurredAt: occurredAt,
      note: note,
      memoryTags: memoryTags,
      scene: scene,
      sourceSessionId: sourceSessionId,
      releaseCount: releaseCount ?? this.releaseCount,
      lastReleasedAt: lastReleasedAt ?? this.lastReleasedAt,
      voiceRecordingId: voiceRecordingId,
    );
  }

  static const Object _keep = Object();

  Map<String, dynamic> toMap() => {
        'id': id,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'kind': kind.name,
        'count': count,
        'moodBefore': moodBefore,
        'moodAfter': moodAfter,
        'emotion': emotion?.name,
        'cardId': cardId,
        'memoryLabel': memoryLabel,
        'crisis': crisis,
        'trigger': trigger.name,
        'occurredAt': occurredAt,
        'note': note,
        'memoryTags': memoryTags,
        'scene': scene,
        'sourceSessionId': sourceSessionId,
        'releaseCount': releaseCount,
        'lastReleasedAt': lastReleasedAt,
        'voiceRecordingId': voiceRecordingId,
      };

  factory ReleaseSession.fromMap(Map raw) {
    final m = _m(raw);
    final tags = m['memoryTags'];
    return ReleaseSession(
      id: _s(m['id']) ?? '',
      startedAt: _i(m['startedAt']) ?? 0,
      endedAt: _i(m['endedAt']),
      kind: enumByName(SessionKind.values, _s(m['kind'])) ?? SessionKind.WORDS4,
      count: _i(m['count']) ?? 0,
      moodBefore: _i(m['moodBefore']),
      moodAfter: _i(m['moodAfter']),
      emotion: enumByName(EmotionTag.values, _s(m['emotion'])),
      cardId: _s(m['cardId']),
      memoryLabel: _s(m['memoryLabel']),
      crisis: m['crisis'] == true,
      trigger: enumByName(SessionTrigger.values, _s(m['trigger'])) ?? SessionTrigger.MANUAL,
      occurredAt: _i(m['occurredAt']),
      note: _s(m['note']),
      memoryTags: tags is List ? tags.whereType<String>().toList() : const [],
      scene: _s(m['scene']),
      sourceSessionId: _s(m['sourceSessionId']),
      releaseCount: _i(m['releaseCount']) ?? 1,
      lastReleasedAt: _i(m['lastReleasedAt']),
      voiceRecordingId: _s(m['voiceRecordingId']),
    );
  }
}

/// 対話の 1 ターン（危機のときは保存しない）。
class ReleaseTurn {
  const ReleaseTurn({
    required this.id,
    this.sessionId,
    required this.at,
    required this.userText,
    required this.reflection,
    this.affirmation,
    this.faqText,
    this.emotion,
    this.trigger = TriggerKind.UNKNOWN,
    this.replayNoteId,
    this.replayText,
    this.cardId,
  });

  final String id;
  final String? sessionId;
  final int at;
  final String userText;

  /// 反映文（無ければ空文字）。
  final String reflection;
  final String? affirmation;

  /// FAQ の答え（あれば）。
  final String? faqText;
  final EmotionTag? emotion;
  final TriggerKind trigger;
  final String? replayNoteId;

  /// 表示した再生リマインドの本文（履歴の再表示用）。
  final String? replayText;
  final String? cardId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'at': at,
        'userText': userText,
        'reflection': reflection,
        'affirmation': affirmation,
        'faqText': faqText,
        'emotion': emotion?.name,
        'trigger': trigger.name,
        'replayNoteId': replayNoteId,
        'replayText': replayText,
        'cardId': cardId,
      };

  factory ReleaseTurn.fromMap(Map raw) {
    final m = _m(raw);
    return ReleaseTurn(
      id: _s(m['id']) ?? '',
      sessionId: _s(m['sessionId']),
      at: _i(m['at']) ?? 0,
      userText: _s(m['userText']) ?? '',
      reflection: _s(m['reflection']) ?? '',
      affirmation: _s(m['affirmation']),
      faqText: _s(m['faqText']),
      emotion: enumByName(EmotionTag.values, _s(m['emotion'])),
      trigger: enumByName(TriggerKind.values, _s(m['trigger'])) ?? TriggerKind.UNKNOWN,
      replayNoteId: _s(m['replayNoteId']),
      replayText: _s(m['replayText']),
      cardId: _s(m['cardId']),
    );
  }
}

/// 「あとで手放す」の待ち行列 1 件。
class PendingEvent {
  const PendingEvent({
    required this.id,
    required this.occurredAt,
    this.source = 'manual',
    this.resolvedSessionId,
  });

  final String id;
  final int occurredAt;

  /// "manual"（Voxna では手動のみ）。
  final String source;

  /// 手放したセッションの id。null なら未処理。
  final String? resolvedSessionId;

  bool get isPending => resolvedSessionId == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'occurredAt': occurredAt,
        'source': source,
        'resolvedSessionId': resolvedSessionId,
      };

  factory PendingEvent.fromMap(Map raw) {
    final m = _m(raw);
    return PendingEvent(
      id: _s(m['id']) ?? '',
      occurredAt: _i(m['occurredAt']) ?? 0,
      source: _s(m['source']) ?? 'manual',
      resolvedSessionId: _s(m['resolvedSessionId']),
    );
  }
}

/// 「書く」画面から手放しシーンへ渡す内容。Luckarise の WriteResult / WriteUiState.toResult を移植。
class WriteResult {
  const WriteResult({
    this.note,
    this.tags = const [],
    this.scene,
    this.keep = true,
    this.meltText,
  });

  /// 書く画面の入力からの組み立て（本文は 300 文字まで。前後の空白を除く）。
  factory WriteResult.from({
    required String text,
    required List<String> tags,
    String? scene,
    required bool keep,
  }) {
    final trimmed = text.trim();
    final clipped = trimmed.length > maxText ? trimmed.substring(0, maxText) : trimmed;
    final melt = clipped.isNotEmpty ? clipped : [...tags, if (scene != null) scene].join(' / ');
    return WriteResult(
      note: keep && clipped.isNotEmpty ? clipped : null,
      tags: List.unmodifiable(tags),
      scene: scene,
      keep: keep,
      meltText: melt.isEmpty ? null : melt,
    );
  }

  /// 「何もなくても、そのまま手放す」。
  const WriteResult.empty({this.keep = true})
      : note = null,
        tags = const [],
        scene = null,
        meltText = null;

  static const int maxText = 300;
  static const int maxTag = 20;
  static const int maxTagOptions = 10;

  /// 保存する本文。「残さない」なら null。
  final String? note;
  final List<String> tags;
  final String? scene;
  final bool keep;

  /// 溶ける演出に出す文字（本文、無ければチップ名、どちらも無ければ null）。
  final String? meltText;

  /// 書く画面のチップ候補: 既定 + よく使う（重複・空を除き最大 10）+ 元の記録のチップ。
  static List<String> tagOptions({
    required List<String> defaultTags,
    required List<String> frequentLabels,
    List<String> sourceTags = const [],
  }) {
    final out = <String>[];
    for (final t in [...defaultTags, ...frequentLabels]) {
      final s = t.trim();
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
      if (out.length >= maxTagOptions) break;
    }
    for (final t in sourceTags) {
      if (!out.contains(t)) out.add(t);
    }
    return out;
  }
}
