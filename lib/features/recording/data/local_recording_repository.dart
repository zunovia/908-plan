import '../../../core/storage/local_db.dart';
import 'recording_model.dart';

class LocalRecordingRepository {
  final LocalDb _db;

  LocalRecordingRepository(this._db);

  Future<void> saveRecording(RecordingModel recording) async {
    await _db.recordings.put(recording.id, recording.toJson());
  }

  List<RecordingModel> getRecordings() {
    return _db.recordings.values
        .map((raw) => RecordingModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  List<RecordingModel> getRecordingsInRange(DateTime from, DateTime to) {
    return getRecordings()
        .where((r) => !r.recordedAt.isBefore(from) && r.recordedAt.isBefore(to))
        .toList();
  }

  int getUniqueDayCount() {
    final days = <String>{};
    for (final r in getRecordings()) {
      days.add(
        '${r.recordedAt.year}-${r.recordedAt.month}-${r.recordedAt.day}',
      );
    }
    return days.length;
  }
}
