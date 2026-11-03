// 手放す機能の端末内保存（Hive の Box<Map> に JSON Map）。Voxna の LocalDb と同じ流儀。
//
// 使い方（main.dart。WP3b が配線する）:
//   await Hive.initFlutter();            // 既存
//   final releaseDb = ReleaseDb();
//   await releaseDb.init();              // localDb.init() の後
//   ProviderScope(overrides: [releaseDbProvider.overrideWithValue(releaseDb), ...])

import 'package:hive_ce/hive_ce.dart';

class ReleaseDb {
  static const String sessionsBoxName = 'release_sessions';
  static const String turnsBoxName = 'release_turns';
  static const String pendingBoxName = 'release_pending';
  static const String settingsBoxName = 'release_settings';

  /// 4 つの箱を開く。Hive.init / Hive.initFlutter の後に呼ぶ。
  Future<void> init() async {
    await Hive.openBox<Map>(sessionsBoxName);
    await Hive.openBox<Map>(turnsBoxName);
    await Hive.openBox<Map>(pendingBoxName);
    await Hive.openBox<Map>(settingsBoxName);
  }

  Box<Map> get sessions => Hive.box<Map>(sessionsBoxName);
  Box<Map> get turns => Hive.box<Map>(turnsBoxName);
  Box<Map> get pending => Hive.box<Map>(pendingBoxName);

  /// 設定は 1 件（キー [ReleaseDb.settingsKey]）に Map で入れる。
  Box<Map> get settings => Hive.box<Map>(settingsBoxName);
  static const String settingsKey = 'settings';

  /// アカウント削除用: 4 つの箱すべてを空にする（設定も消える）。
  Future<void> clearAll() async {
    await sessions.clear();
    await turns.clear();
    await pending.clear();
    await settings.clear();
  }
}
