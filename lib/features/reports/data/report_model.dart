class DailyMetric {
  final DateTime date;
  final double energy;
  final double clarity;
  final double expressionRange;
  final double tempo;

  const DailyMetric({
    required this.date,
    required this.energy,
    required this.clarity,
    required this.expressionRange,
    this.tempo = 3.0,
  });

  factory DailyMetric.fromJson(Map<String, dynamic> json) {
    return DailyMetric(
      date: DateTime.parse(json['date'] as String),
      energy: (json['energy'] as num).toDouble(),
      clarity: (json['clarity'] as num).toDouble(),
      expressionRange: (json['expression_range'] as num).toDouble(),
      tempo: (json['tempo'] as num?)?.toDouble() ?? 3.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'energy': energy,
        'clarity': clarity,
        'expression_range': expressionRange,
        'tempo': tempo,
      };
}
