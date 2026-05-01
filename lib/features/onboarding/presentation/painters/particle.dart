import 'dart:math';

class Particle {
  final double angle;
  final double baseRadius;
  final double speed;
  final double size;
  final double phaseOffset;

  const Particle({
    required this.angle,
    required this.baseRadius,
    required this.speed,
    required this.size,
    required this.phaseOffset,
  });

  static List<Particle> generate(int count, {Random? random}) {
    final rng = random ?? Random(42);
    return List.generate(count, (i) {
      return Particle(
        angle: (2 * pi / count) * i + rng.nextDouble() * 0.5,
        baseRadius: 40.0 + rng.nextDouble() * 30.0,
        speed: 0.8 + rng.nextDouble() * 0.4,
        size: 1.5 + rng.nextDouble() * 2.0,
        phaseOffset: rng.nextDouble() * 2 * pi,
      );
    });
  }
}
