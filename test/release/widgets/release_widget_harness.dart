// 手放す画面のウィジェットテスト用の土台。
// Hive はメモリ上の箱（ファイル IO は testWidgets の偽の時間では終わらないため）、
// コンテンツは File から読み、google_fonts は使わない（RelStyles.plainFonts）。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zero_app/core/constants/app_colors.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/release_settings.dart';
import 'package:zero_app/features/release/presentation/release_routes.dart';
import 'package:zero_app/features/release/presentation/release_tts.dart';
import 'package:zero_app/features/release/presentation/release_ui.dart';
import 'package:zero_app/features/release/presentation/widgets/rel_styles.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';
import 'package:zero_app/shared/widgets/zero_bottom_nav.dart';

import '../release_test_helpers.dart';

/// 読み上げの代わり（話した言葉を記録するだけ）。
class FakeTts extends ReleaseTts {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text, AppLang lang) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

/// 2026-10-18（日）10:00。
final int fixedNow = DateTime(2026, 10, 18, 10).millisecondsSinceEpoch;

class ReleaseHarness {
  ReleaseHarness._();

  static final ReleaseDb db = ReleaseDb();
  static Directory? _tmp;

  /// setUpAll で呼ぶ（メモリ上の 4 箱を開く）。
  static Future<void> open() async {
    RelStyles.plainFonts = true;
    _tmp = await Directory.systemTemp.createTemp('release_widgets');
    Hive.init(_tmp!.path);
    for (final name in [
      ReleaseDb.sessionsBoxName,
      ReleaseDb.turnsBoxName,
      ReleaseDb.pendingBoxName,
      ReleaseDb.settingsBoxName,
    ]) {
      await Hive.openBox<Map>(name, bytes: Uint8List(0));
    }
  }

  /// tearDownAll で呼ぶ。
  static Future<void> close() async {
    await Hive.close();
    try {
      await _tmp?.delete(recursive: true);
    } catch (_) {}
  }

  /// setUp で呼ぶ（記録と設定を空に）。
  static Future<void> reset() => db.clearAll();

  /// 設定を保存する（初回説明の同意・ループ速度など）。
  static Future<void> saveSettings({bool accepted = true, String loopSpeed = 'off', bool tts = false}) async {
    final base = ReleaseSettings.fromMap(db.settings.get(ReleaseDb.settingsKey));
    await db.settings.put(
      ReleaseDb.settingsKey,
      base
          .copyWith(
            disclaimerAcceptedAt: accepted ? fixedNow : null,
            loopSpeed: loopSpeed,
            ttsEnabled: tts,
          )
          .toMap(),
    );
  }

  static ProviderContainer container({
    FakeTts? tts,
    Map<String, List<String>> voiceTags = const {},
    List<Override> extra = const [],
  }) {
    return ProviderContainer(overrides: [
      ...extra,
      releaseDbProvider.overrideWithValue(db),
      contentAssetLoaderProvider.overrideWithValue(const FileContentLoader()),
      releaseClockProvider.overrideWithValue(() => fixedNow),
      releaseContentLangProvider.overrideWithValue(AppLang.ja),
      releaseTtsProvider.overrideWithValue(tts ?? FakeTts()),
      releaseVoiceTagsProvider.overrideWith((ref, id) => voiceTags[id] ?? const []),
    ]);
  }

  /// 下部タブ（5 つ）＋手放すルートだけのルーター。
  static GoRouter router(ProviderContainer c, {required String initialLocation}) {
    final rootKey = GlobalKey<NavigatorState>();
    Widget placeholder(String label) => Scaffold(body: Center(child: Text(label)));
    return GoRouter(
      navigatorKey: rootKey,
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child, bottomNavigationBar: const ZeroBottomNav()),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => placeholder('HOME')),
            GoRoute(path: '/reports', builder: (_, __) => placeholder('REPORTS')),
            GoRoute(path: '/history', builder: (_, __) => placeholder('HISTORY')),
            releaseTabRoute(
              rootNavigatorKey: rootKey,
              isIntroAccepted: () => c.read(releaseSettingsProvider).disclaimerAccepted,
            ),
            GoRoute(path: '/settings', builder: (_, __) => placeholder('SETTINGS')),
          ],
        ),
      ],
    );
  }

  /// テスト用の明るいテーマ（Voxna の色、google_fonts なし）。
  static ThemeData get theme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightSurfacePrimary,
        colorScheme: const ColorScheme.light(
          surface: AppColors.lightSurfacePrimary,
          surfaceContainerHighest: AppColors.lightSurfaceSecondary,
          primary: AppColors.lightAccentWarm,
          onPrimary: AppColors.lightSurfacePrimary,
          secondary: AppColors.lightAccentCool,
          onSurface: AppColors.lightTextPrimary,
        ),
      );

  /// アプリを組み立てて表示する（アニメーションを減らす設定で）。
  static Future<GoRouter> pump(
    WidgetTester tester,
    ProviderContainer c, {
    required String initialLocation,
    bool reduceMotion = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final r = router(c, initialLocation: initialLocation);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: theme,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: r,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
    return r;
  }

  /// 非同期の読み込みを進める（無限アニメーションがあるので pumpAndSettle は使わない）。
  static Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  static AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));
}

/// 待ちの描画用。
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final steps = d.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// ReleaseScene のパス（テストで直接開く）。
const String scenePath = ReleasePaths.scene;
