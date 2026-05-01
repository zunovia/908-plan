import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';

void main() {
  group('RecordingModel', () {
    test('toJson produces expected keys', () {
      final model = RecordingModel(
        id: 'abc-123',
        recordedAt: DateTime(2025, 5, 1, 10, 30),
        durationSeconds: 30,
        energy: 0.7,
        clarity: 0.8,
        expressionRange: 0.5,
        tempo: 3.2,
        selfAssessment: '穏やか',
      );

      final json = model.toJson();

      expect(json['id'], 'abc-123');
      expect(json['recorded_at'], '2025-05-01T10:30:00.000');
      expect(json['duration_seconds'], 30);
      expect(json['energy'], 0.7);
      expect(json['clarity'], 0.8);
      expect(json['expression_range'], 0.5);
      expect(json['tempo'], 3.2);
      expect(json['self_assessment'], '穏やか');
    });

    test('fromJson roundtrips correctly', () {
      final original = RecordingModel(
        id: 'test-id',
        recordedAt: DateTime(2025, 4, 15, 8, 0),
        durationSeconds: 60,
        energy: 0.65,
        clarity: 0.9,
        expressionRange: 0.3,
        tempo: 2.8,
        selfAssessment: '普通',
      );

      final restored = RecordingModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.recordedAt, original.recordedAt);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.energy, original.energy);
      expect(restored.clarity, original.clarity);
      expect(restored.expressionRange, original.expressionRange);
      expect(restored.tempo, original.tempo);
      expect(restored.selfAssessment, original.selfAssessment);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'minimal',
        'recorded_at': '2025-03-10T12:00:00.000',
        'duration_seconds': 30,
        'energy': null,
        'clarity': null,
        'expression_range': null,
        'tempo': null,
        'self_assessment': null,
      };

      final model = RecordingModel.fromJson(json);

      expect(model.id, 'minimal');
      expect(model.durationSeconds, 30);
      expect(model.energy, isNull);
      expect(model.clarity, isNull);
      expect(model.expressionRange, isNull);
      expect(model.tempo, isNull);
      expect(model.selfAssessment, isNull);
    });

    test('toJson includes null values for optional fields', () {
      final model = RecordingModel(
        id: 'no-metrics',
        recordedAt: DateTime(2025, 1, 1),
        durationSeconds: 30,
      );

      final json = model.toJson();

      expect(json.containsKey('energy'), isTrue);
      expect(json['energy'], isNull);
      expect(json.containsKey('self_assessment'), isTrue);
      expect(json['self_assessment'], isNull);
    });
  });
}
