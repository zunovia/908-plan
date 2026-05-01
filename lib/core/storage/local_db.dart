import 'package:hive_ce/hive_ce.dart';

class LocalDb {
  static const _recordingsBox = 'recordings';

  Future<void> init() async {
    await Hive.openBox<Map>(_recordingsBox);
  }

  Box<Map> get recordings => Hive.box<Map>(_recordingsBox);

  Future<void> clearAll() async {
    await recordings.clear();
  }
}
