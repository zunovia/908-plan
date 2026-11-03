# release（手放す）機能 API リファレンス（WP1 → WP3a/WP3b 向け）

UI（WP3a/WP3b）が呼ぶ公開 API の一覧。シグネチャはコードどおり。`domain/` は純 Dart（flutter を import しない）。
列挙値の名前（`.name`）は JSON・保存値・ルート引数と同じ大文字（例 `SessionKind.WORDS4.name == 'WORDS4'`）。

## 0. 配線（WP3b）

```dart
// main.dart（Hive.initFlutter() と LocalDb.init() の後）
final releaseDb = ReleaseDb();
await releaseDb.init();
ProviderScope(overrides: [
  releaseDbProvider.overrideWithValue(releaseDb),   // 必須（無いと StateError）
  ...
]);

// アカウント削除（settings_provider.dart の deleteAccountData 内）
await ref.read(releaseDbProvider).clearAll();      // 4 箱すべて
ref.invalidate(releaseSettingsProvider);
```

pubspec: `crypto: ^3.0.3`, `flutter_tts: 4.2.3`（4.2.4 以降は Kotlin 2.2.20 / compileSdk 36 を要求し、Flutter 3.27 の Android テンプレートと合わないため固定）。
アセット: `assets/release/{en,ja,es,pt,common}/`。

## 1. Providers（`providers/release_providers.dart`）

| Provider | 型 | 内容 |
|---|---|---|
| `releaseDbProvider` | `Provider<ReleaseDb>` | main で override 必須 |
| `releaseClockProvider` | `Provider<int Function()>` | 現在時刻 epoch ms（テストで差し替え） |
| `contentAssetLoaderProvider` | `Provider<ContentAssetLoader>` | 既定 `RootBundleContentLoader` |
| `contentRepositoryProvider` | `Provider<ContentRepository>` | |
| `releaseContentProvider` | `FutureProvider<LoadedContent>` | 全コンテンツ（キャッシュ） |
| `releaseSettingsRepositoryProvider` | `Provider<ReleaseSettingsRepository>` | |
| `releaseRepositoryProvider` | `Provider<ReleaseRepository>` | 記録・セッション |
| `dialogueRepositoryProvider` | `Provider<DialogueRepository>` | 対話・安全判定 |
| `releaseDomainProvider` | `FutureProvider<ReleaseDomain>` | SafetyGate/OutputGate/CardSelector/ReplayReminder/DialogueEngine |
| `releaseContentLangProvider` | `Provider<AppLang>` | Voxna の `settingsProvider.localeCode`（'system'\|'ja'\|'en'\|'es'\|'pt'）→ AppLang。system は端末言語、対応外は en |
| `releaseSettingsProvider` | `NotifierProvider<ReleaseSettingsNotifier, ReleaseSettings>` | 手放す系の設定（下記） |
| `releaseSummaryProvider` | `StreamProvider<ReleaseSummary>` | 今月の回数・7 日点灯・おかえり・今日の回数（Hive 変更で自動更新） |
| `releaseRecordsProvider` | `StreamProvider<List<ReleaseSession>>` | 残した記録（最後に手放した順） |
| `releasePendingProvider` | `StreamProvider<List<PendingEvent>>` | 未処理の「あとで手放す」 |
| `releaseFrequentTagsProvider` | `StreamProvider<List<({String tag, int count})>>` | よく手放した記憶（最大 8） |
| `releaseWeeklyStatsProvider` | `StreamProvider<WeeklyStats?>` | 今週の手紙の事実（0 回なら null） |
| `releaseCountsByMonthProvider` | `StreamProvider.family<Map<DateTime, int>, DateTime>` | その月の日別回数。キーはローカル 0 時の `DateTime(y,m,d)` |
| `releaseTodayCardProvider` | `FutureProvider<TodayCard>` | 今日の一枚（語 + 一文） |
| `releaseCrisisBannerProvider` | `Provider<bool>` | 最後の危機判定から 24 時間以内 |
| `releaseFreeTextAllowedProvider` | `FutureProvider<bool>` | その言語に crisis.json がある（無ければ自由入力を出さない：対話・書く） |
| `releaseWordSetProvider` | `FutureProvider<ReleaseWordSet>` | 手放しシーンの言葉の組 |

### ReleaseSettingsNotifier（`ref.read(releaseSettingsProvider.notifier)`）
すべて `Future<void>`。保存後に state が更新される（他経路の保存も watch で反映）。
`setTtsEnabled(bool)`, `setHapticsEnabled(bool)`, `setGoalCount(int)`, `setLoopSpeed(LoopSpeed)`,
`setBreathPattern(int in, int hold, int out)`, `setQuietHours(String start, String end)`（"HH:mm"）,
`setPauseUntil(int epochMillis)`, `pauseOneWeek()`, `cancelPause()`, `setReplayMode(ReplayMode)`,
`acceptDisclaimer()`（初回説明の同意＝今の時刻）, `setCustomWords(List<String>)`, `setReleaseTool(String id)`,
`setOwnTools(List<String>)`, `setKeepNotes(bool)`, `setTriggerCues(List<TriggerCue>)`, `setTriggerSentence(String)`,
`setCheckinMorning({bool? enabled, String? time})`, `setCheckinEvening({bool? enabled, String? time})`,
`setZeroDay({bool? enabled, String? time})`, `pushRecentCardId(String)`, `pushRecentReplayId(String)`, `void reload()`。

## 2. 設定 `ReleaseSettings`（`domain/release_settings.dart`、不変・`copyWith`・`toMap`/`fromMap`）

| フィールド | 型 | 既定 |
|---|---|---|
| ttsEnabled | bool | false |
| hapticsEnabled | bool | true |
| goalCount | int | 27 |
| loopSpeed | String ("off"/"slow"/"normal"/"fast") | "normal"（`loopSpeedValue` で `LoopSpeed`） |
| breathIn / breathHold / breathOut | int | 4 / 4 / 8 |
| quietStart / quietEnd | String "HH:mm" | "22:00" / "07:00" |
| pauseUntil | int epoch ms | 0 |
| replayMode | ReplayMode | EVERY |
| disclaimerAcceptedAt | int? | null（`disclaimerAccepted` で bool。null なら `/release/intro`） |
| lastCrisisAt | int | 0 |
| recentReplayIds / recentCardIds / recentReflectionIds | List<String> | [] |
| customWords | List<String>（最大 8・24 文字） | []（空なら words.json の four） |
| releaseTool | String（"set" / "word:<id>" / "own:<本文>"） | "set" |
| ownTools | List<String>（最大 10・40 文字） | [] |
| keepNotes | bool | true |
| triggerCues | List<TriggerCue> | [] |
| triggerSentence | String（60 文字まで） | ""（通知タイトルに使う） |
| checkinMorningEnabled / checkinMorningTime | bool / String | false / "07:30" |
| checkinEveningEnabled / checkinEveningTime | bool / String | false / "21:00" |
| zeroDayEnabled / zeroDayTime | bool / String | false / "20:00" |

`ReleaseSettingsRepository`（同名の setter 群は `Future<ReleaseSettings>` を返す）: `ReleaseSettings get current`, `Stream<ReleaseSettings> watch()`, `save(ReleaseSettings)`, `update(ReleaseSettings Function(ReleaseSettings))`, `setDisclaimerAcceptedAt(int?)`, `setLastCrisisAt(int)`, `pushRecentReflectionId(String)`, `reset()`。

## 3. 記録 `ReleaseRepository`（`data/release_repository.dart`）

セッションは **最初のタップで** `startSession`、**0 回で終えたら** `discardSession`（UI の責務。Luckarise と同じ）。

```dart
Future<String> startSession({required SessionKind kind, EmotionTag? emotion, String? cardId, int? moodBefore,
  SessionTrigger trigger = SessionTrigger.MANUAL, String? note, List<String> tags = const [], String? scene,
  String? sourceSessionId, int? occurredAt, String? voiceRecordingId});
Future<void> finishSession(String id, int count, {int? moodAfter, String? memoryLabel}); // 元記録(sourceSessionId)の releaseCount+1
Future<void> setMoodAfter(String id, int? moodAfter);
Future<void> setMemoryLabel(String id, String? memoryLabel);
Future<void> discardSession(String id);
Future<void> deleteRecord(String id);               // 元の記録と「もう一度」の子を両方消す
ReleaseSession? sessionById(String id);
ReleaseDraft? releaseAgainDraft(String sourceSessionId); // {sourceSessionId, note, tags, scene} → 書く画面の初期値。
                                                         // その後 startSession(sourceSessionId: ...) → finishSession
List<ReleaseSession> allSessions();                 // 開始の新しい順（危機・未完了含む）
List<ReleaseSession> completedSessions();
int completedTotal();
List<ReleaseSession> records();                     // 本文あり・完了・子でない。最後に手放した順
static List<String> recordFilterTags(List<ReleaseSession> records); // 記録の絞り込みチップ（多い順）
List<ReleaseSession> sessionsBetween(int fromMs, int toMs);
List<ReleaseSession> sessionsOnDay(DateTime day);
int? lastSessionAt();
List<PracticeMark> marks();
ReleaseSummary summary();       // {monthCount, last7(List<bool> 古い順・最後が今日), welcomeBack, hasAny, todayCount}
int monthCount();  List<bool> last7Days();  WeeklyStats? weeklyStats();
int todayCount();  bool isTodayEmpty();                       // todayCount = 今日開始の非危機セッションの count 合計
Map<DateTime, int> countsByDay(DateTime from, DateTime to);   // 完了セッション数。キー DateTime(y,m,d)
List<({String tag, int count})> frequentTags({int limit = 8});
List<({String label, int count})> topMemoryLabels(int n);     // 書く画面のチップ候補
Future<String> addPendingEvent(int occurredAt, {String source = 'manual'});
List<PendingEvent> pendingEvents();  PendingEvent? pendingEventById(String id);
Future<void> resolvePendingEvent(String id, String sessionId);
Future<void> deletePendingEvent(String id);
Future<void> deleteAll();      // セッション・対話・待ち行列（設定は残す）
Stream<void> watch();          // sessions / pending の変更
DateTime today();  bool isNight();  int nowMillis();
```

`ReleaseSession`（`domain/records.dart`）: `id, startedAt, endedAt?, kind, count, moodBefore?, moodAfter?, emotion?, cardId?, memoryLabel?, crisis, trigger, occurredAt?, note?, memoryTags(List<String>), scene?, sourceSessionId?, releaseCount, lastReleasedAt?, voiceRecordingId?`、`isCompleted`, `isRecord`, `sortAt`。
`PendingEvent`: `id, occurredAt, source, resolvedSessionId?, isPending`。
`ReleaseTurn`: `id, sessionId?, at, userText, reflection, affirmation?, faqText?, emotion?, trigger, replayNoteId?, replayText?, cardId?`。

### 書く画面 `WriteResult`（`domain/records.dart`）
```dart
WriteResult.from({required String text, required List<String> tags, String? scene, required bool keep});
const WriteResult.empty({bool keep = true});          // 「何もなくても、そのまま手放す」
// note（keep=false or 空なら null）, tags, scene, keep, meltText（本文→チップ名→null）
static List<String> tagOptions({required List<String> defaultTags, required List<String> frequentLabels, List<String> sourceTags});
static const maxText = 300, maxTag = 20, maxTagOptions = 10;
```
**安全（設計 §5）**: 書く画面の本文は `dialogueRepository.checkSafety(text)` を通す。`isCrisis` → `recordCrisis()` して本文を保存せず `/release/crisis`（`abuseContext` なら `?abuse=1`）。`isSoft` → 窓口バナーを出して続行。`abuseContext` のときは再生リマインドを出さない。

## 4. 対話 `DialogueRepository`（`data/dialogue_repository.dart`、RULE のみ・外部送信なし）

```dart
Future<RespondResult> respond({required String text, EmotionTag? emotionHint, required AppLang lang,
  String? sessionId, Scene? scene, bool replayShownInSession = false});   // text は 300 字で切る
// RespondResult{DialogueOutcome outcome, String? turnId}
//   DialogueCrisis{bool abuse}  → 本文は保存せず crisis セッションと lastCrisisAt のみ記録済み。/release/crisis へ
//   DialogueReply{TurnResult turn}
// TurnResult: reflectionId?, reflection?, affirmationId?, affirmation?, faqText?, emotion?, trigger, replay(ReplayItem?),
//             card(CardItem?), route(RouteId.RULE), softCrisis, abuseContext
// 表示順（Luckarise）: reflection → replay.text → (faqText ?? affirmation) → card
Future<SafetyResult> checkSafety(String text);      // SafetyResult{level, abuseContext, categories, isCrisis, isSoft}
Future<bool> isFreeTextAllowed(AppLang lang);
Future<void> recordCrisis();
Future<CardItem?> anotherCard({required String previousCardId, EmotionTag? emotion, TriggerKind? trigger, required AppLang lang});
List<ReleaseTurn> turns({String? sessionId});  List<ReleaseTurn> recentTurns(int limit);  Future<void> clearTurns();
Future<ReleaseDomain> domain();
```

## 5. コンテンツ `ContentRepository` / `LoadedContent`（`data/content_repository.dart`）

`Future<LoadedContent> bundle()`、`cards(lang)`, `words(lang)`, `notes(lang)`, `today(lang)`, `child(lang)`, `surrender(lang)`, `notifications(lang)`, `wheel(lang)`, `quotes(lang)`, `replay(lang)`, `helplines()`, `crisis(lang)`（**フォールバックしない**）。他は lang に無ければ en。
`LoadedContent` は各 `Map<AppLang, ...>`（cards, replay, reflections, affirmations, faqs, lexicons, triggers, crisis, words, notes, today, child, surrender, quotes, notifications, wheel）と `outputGate`, `helplines`。

主なモデル（`domain/content_models.dart`）: `WordsFile{four, items, idsToText(ids), textFor(id)}`, `ChildItem{id,text,night}`, `SurrenderItem{id,text,night}`, `NoteItem`, `TodayItem`, `NotificationItem{id,slot,text}`, `ReplayItem{id,category,text,slot?}`, `CardItem{id,kind,emotions,triggers,scenes,text,prompt?,repeat?,words,breath?,preScene?,lang}`, `Reflection`, `Affirmation`, `FaqItem`, `Lexicon`, `Triggers`, `CrisisLexicon`, `WheelFile/WheelCore/WheelChild{id,label,emotion}`, `QuoteItem{id,text,source}`, `Helplines{countries, fallbackUrl, countryCodes, country(code)}`, `HelplineCountry{code, lines}`, `HelplineEntry{id, name, number, sms?, hours, kind("CRISIS"/"ABUSE")}`, `LocalizedText{en, ja, es?, pt?, forLang(AppLang)}`（無い言語は en）。

## 6. ドメイン（純 Dart）

- `models.dart`: `AppLang{en,ja,es,pt; code; fromTag()}`, `contentLangFor(localeCode, systemLanguageCode)`, `CardKind`, `EmotionTag`(+`priority`), `ReplayMode`, `RouteId{RULE}`, `SafetyLevel{OK,CRISIS_SOFT,CRISIS}`, `Scene`, `SessionKind`, `SessionTrigger{MANUAL,QUICK,TIME,EVENT,WEARABLE}`, `TriggerKind`, `TriggerCue{timed; encode/decode}`, `LoopSpeed{OFF,SLOW(2500),NORMAL(1600),FAST(1000); intervalMillis; fromSetting(); settingValue}`, `TimeRules{isNightHour, epochDay(DateTime), dateOfEpochDay(int), epochDayOfMillis}`, `TimeText{parse→({hour,minute})?, format}`, `RecentIds`, `CustomWords`, `enumByName()`。
- `release_tools.dart`（`own_tools.dart` を export）:
  - `ReleaseMode{WORDS4,WORDS1,IDK,CROSS,PRE; fromName(String?); toolsApply; sessionKind}`
  - `ReleaseWordSet.build(WordsFile?, List<String> customWords)` → `fourWords, idkWord, words1Pool, allWords`; `initial(mode, {required String savedTool, required List<String> ownTools, CardItem? card})` → `({List<String> words, String selectedTool, List<ToolOption> tools})`（ツールが効かない場面は selectedTool '' / tools 空）; `toolOptions(mode, ownTools)`; `wordsForTool(mode, ToolOption)`; `baseWordsFor(mode, {CardItem? card})`; `quickGoal = 3`（15 秒のひと言）; `crossMark = '×'`。
  - `ToolOption{id, words, own, text}`、`ReleaseTools{set, wordId(), ownId(), options(), resolve()}`、`OwnTools{maxTools=10, maxLength=40, normalizeOne(), normalize(), encode(), decode(), clip()}`。
  - シーンの規則（Luckarise）: タップごとに count+1・語を循環、目標到達は goal（quick は 3、PRE 等は card.repeat ?? goalCount）、4 回ごとに notes を次へ、ツール切替で回数は保持・語は先頭から、自分のツール追加は上限 10（既存なら選ぶだけ）。
- `tts_lang.dart`: `AppLang ttsLangFor(String word, AppLang uiLang)`, `String ttsLocaleTag(AppLang)`（ja-JP / en-US / es-ES / pt-BR）。
- `today_pick.dart`: `TodayPick.pick<T>(items, epochDay, {salt})`, `lineSalt = 7`, `TodayPick.card({words, customWords, today, date}) → TodayCard{word, line?}`。
- `weekly_letter.dart`: `PracticeMark(DateTime day, [tags])`, `WeeklyStats{weekStart, thisWeekCount, lastWeekCount, topTag?, topTagCount, restDays(List<int> DateTime.monday..sunday)}`, `WeeklyLetter.{weekStartOf, stats, last7, monthCount, isWelcomeBack, isMilestone}`（節目 7/30/100/365）。
- `crisis_logic.dart`: `CrisisLogic.resolveInitialCountryCode({systemCountry='', simCountry='', networkCountry='', defaultCountry='', required appLang, required availableCodes})`（Flutter は SIM/ネットワーク国を取れないので空でよい。systemCountry は `PlatformDispatcher.instance.locale.countryCode ?? ''`）, `resolveInitialCountryCodeFrom(raw, codes)`, `sortedLines(lines, {required bool abuse})`（ABUSE を先頭・安定）, `displayLabel(code)`（GB→UK）, `isBannerVisible(lastCrisisAt, now)`, `otherCountryCode = 'OTHER'`。
- `schedule_math.dart`（package:timezone）: `ScheduleMath.plan({now, zone, morningEnabled, morningTime, eveningEnabled, eveningTime, zeroDayEnabled, zeroDayTime, quietStart, quietEnd, pauseUntil}) → List<PlannedReminder{notificationId(2001/2002/2003), reminderId('morning'/'evening'/'zero_day'), slot('MORNING'/'NIGHT'), atMillis}>`、`nextFixed(...)`, `isQuiet(ClockTime,...)`, `parseTime(String?)`, `slotFor(reminderId)`, `notificationTextIndex(epochDay, reminderId, size)`（Luckarise と同じ文の選び方）, `shouldSkipZeroDay(reminderId, todayCount)`, `idTriggerBase = 2100`。通知タイトルは `triggerSentence`（空ならアプリ名）。
- `voice_tendency.dart`: `VoiceTendency.tagsForRecording(RecordingModel current, List<RecordingModel> previous, {int maxTags = 2}) → List<String>`（直近 14 件の平均と比較。3 件未満なら []）。タグ: `voice:low_energy`, `voice:fast_tempo`, `voice:narrow_range`, `voice:low_clarity`, `voice:steady`（`VoiceTendency.allTags`）。Write の記憶チップの選択済み下書きに入れ、表示は l10n で置き換える（`memoryTags` にはこの文字列のまま保存される）。
- `safety_gate.dart` / `output_gate.dart` / `rule_route.dart` / `dialogue_engine.dart` / `card_selector.dart` / `replay_reminder.dart`: 通常は `ReleaseDomain`（`releaseDomainProvider`）経由で使う。`ReplayReminder.pick({required trigger, emotion, required locale, recentIds, isNight, abuseContext, softCrisis})`, `daily(locale, dayIndex)`, `byId(id, locale)`；`CardSelector.select({emotion, trigger, kind, scene, recentIds, required locale})`, `byId(id, locale)`, `preCards(locale)`；`OutputGate.isClean(text)`。
- 手放しシーンの子どもへの一文・委ねる一文（Luckarise と同じ）: `child.items.where((i) => i.night == isNight)`（空なら全件）からランダム、`surrender` も同様。再生リマインド: `replayMode == OFF` なら出さない、`replayId` 指定があれば `byId`、無ければ `pick(trigger: UNKNOWN, locale, isNight)`。
