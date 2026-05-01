import 'dart:async';
import 'package:record/record.dart';

class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> start({
    required String path,
    Duration amplitudeInterval = const Duration(milliseconds: 100),
    void Function(Amplitude)? onAmplitude,
  }) async {
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    if (onAmplitude != null) {
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(amplitudeInterval)
          .listen(onAmplitude);
    }
  }

  Future<String?> stop() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    return await _recorder.stop();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<void> dispose() async {
    _amplitudeSubscription?.cancel();
    await _recorder.dispose();
  }
}
