// 手放す機能のルート（app.dart の ShellRoute に入れる）。
// タブ `/release` の下に全画面のルートを置き、ルートの Navigator（下部タブの上）に積む。
// 初回説明に同意していなければ、説明と相談窓口以外は `/release/intro?from=...` へ回す。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'release_ui.dart';
import 'screens/breath_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/crisis_screen.dart';
import 'screens/done_screen.dart';
import 'screens/records_screen.dart';
import 'screens/release_home_screen.dart';
import 'screens/release_intro_screen.dart';
import 'screens/release_scene_screen.dart';
import 'screens/write_screen.dart';

/// 同意前に開いてよいパス。
const Set<String> _openWithoutIntro = {ReleasePaths.intro, ReleasePaths.crisis};

/// 初回説明の門。[isIntroAccepted] が例外を投げたら（DB 未配線など）通す。
String? releaseIntroRedirect(GoRouterState state, bool Function() isIntroAccepted) {
  final path = state.uri.path;
  if (!path.startsWith(ReleasePaths.home) || _openWithoutIntro.contains(path)) return null;
  bool accepted;
  try {
    accepted = isIntroAccepted();
  } catch (_) {
    return null;
  }
  if (accepted) return null;
  return Uri(path: ReleasePaths.intro, queryParameters: {'from': state.uri.toString()}).toString();
}

String? _q(GoRouterState state, String key) {
  final v = state.uri.queryParameters[key];
  return (v == null || v.isEmpty) ? null : v;
}

/// 下部タブ「手放す」とその下の全画面ルート。
GoRoute releaseTabRoute({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required bool Function() isIntroAccepted,
}) {
  GoRoute full(String path, Widget Function(GoRouterState state) build) => GoRoute(
        path: path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => build(state),
      );

  return GoRoute(
    path: ReleasePaths.home,
    redirect: (_, state) => releaseIntroRedirect(state, isIntroAccepted),
    builder: (_, __) => const ReleaseHomeScreen(),
    routes: [
      full('intro', (s) => ReleaseIntroScreen(next: _q(s, 'from'))),
      full(
        'write',
        (s) => WriteScreen(
          voiceRecordingId: _q(s, 'voice'),
          sourceSessionId: _q(s, 'source'),
          pendingEventId: _q(s, 'pending'),
        ),
      ),
      full('scene', (s) {
        final extra = s.extra;
        final args = extra is ReleaseSceneArgs ? extra : ReleaseSceneArgs.fromQuery(s.uri.queryParameters);
        return ReleaseSceneScreen(args: args);
      }),
      full('quick', (_) => const ReleaseSceneScreen(args: ReleaseSceneArgs.quick())),
      full('done', (s) => DoneScreen(sessionId: _q(s, 'session') ?? '')),
      full('records', (_) => const RecordsScreen()),
      full('chat', (_) => const ChatScreen()),
      full('crisis', (s) => CrisisScreen(abuse: s.uri.queryParameters['abuse'] == '1')),
      full(
        'breath',
        (s) => BreathScreen(cardId: _q(s, 'card'), emotion: enumByName(EmotionTag.values, _q(s, 'emotion'))),
      ),
    ],
  );
}
