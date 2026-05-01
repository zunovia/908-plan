import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/recording_provider.dart';

class WaveformVisualizer extends ConsumerStatefulWidget {
  const WaveformVisualizer({super.key});

  @override
  ConsumerState<WaveformVisualizer> createState() =>
      _WaveformVisualizerState();
}

class _WaveformVisualizerState extends ConsumerState<WaveformVisualizer> {
  static const int _maxSamples = 30;
  final List<double> _amplitudeHistory = List.filled(_maxSamples, 0.0);

  @override
  Widget build(BuildContext context) {
    // Use ref.listen to update amplitude history outside of build's return.
    ref.listen<double>(
      recordingProvider.select((s) => s.currentAmplitude),
      (_, next) {
        setState(() {
          _amplitudeHistory.removeAt(0);
          _amplitudeHistory.add(next);
        });
      },
    );

    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_maxSamples, (index) {
          final value = _amplitudeHistory[index];
          final barHeight = 4.0 + value * 96.0; // min 4, max 100
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 4,
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4 + value * 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
