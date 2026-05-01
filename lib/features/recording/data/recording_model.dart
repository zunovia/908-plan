class RecordingModel {
  final String id;
  final DateTime recordedAt;
  final int durationSeconds;
  final double? energy;
  final double? clarity;
  final double? expressionRange;
  final double? tempo;
  final String? selfAssessment;

  const RecordingModel({
    required this.id,
    required this.recordedAt,
    required this.durationSeconds,
    this.energy,
    this.clarity,
    this.expressionRange,
    this.tempo,
    this.selfAssessment,
  });

  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    return RecordingModel(
      id: json['id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      durationSeconds: json['duration_seconds'] as int,
      energy: (json['energy'] as num?)?.toDouble(),
      clarity: (json['clarity'] as num?)?.toDouble(),
      expressionRange: (json['expression_range'] as num?)?.toDouble(),
      tempo: (json['tempo'] as num?)?.toDouble(),
      selfAssessment: json['self_assessment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recorded_at': recordedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'energy': energy,
      'clarity': clarity,
      'expression_range': expressionRange,
      'tempo': tempo,
      'self_assessment': selfAssessment,
    };
  }
}
