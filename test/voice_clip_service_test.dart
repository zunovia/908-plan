import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wav/wav.dart';
import 'package:zero_app/core/audio/voice_clip_service.dart';

Float64List _sine(int sampleRate, double seconds, {double freq = 220}) {
  final n = (sampleRate * seconds).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = 0.5 * sin(2 * pi * freq * i / sampleRate);
  }
  return out;
}

void main() {
  group('VoiceClipService pure helpers', () {
    test('extractClip keeps only the first N seconds', () {
      final samples = _sine(1000, 10);
      final clip = VoiceClipService.extractClip(samples, 1000, seconds: 3);
      expect(clip.length, 3000);
      expect(clip[0], samples[0]);
      expect(clip[2999], samples[2999]);
    });

    test('extractClip returns short input unchanged', () {
      final samples = _sine(1000, 1);
      final clip = VoiceClipService.extractClip(samples, 1000, seconds: 3);
      expect(clip.length, 1000);
    });

    test('downsample halves 44100 to 22050 by averaging pairs', () {
      final samples = Float64List.fromList([1, 3, 5, 7, 9, 11]);
      final result = VoiceClipService.downsample(samples, 44100, 22050);
      expect(result.sampleRate, 22050);
      expect(result.samples, [2.0, 6.0, 10.0]);
    });

    test('downsample leaves non-integer ratios untouched', () {
      final samples = Float64List.fromList([1, 2, 3]);
      final result = VoiceClipService.downsample(samples, 48000, 22050);
      expect(result.sampleRate, 48000);
      expect(result.samples, samples);
    });

    test('applyFades zeroes the very first and last samples', () {
      final samples = Float64List.fromList(List.filled(2000, 1.0));
      final faded = VoiceClipService.applyFades(samples, 1000);
      expect(faded.first, 0.0);
      expect(faded.last, closeTo(0.0, 1e-9));
      expect(faded[1000], 1.0);
      // input is not mutated
      expect(samples.first, 1.0);
    });

    test('concatWithGaps inserts silence between parts', () {
      final a = Float64List.fromList([1, 1]);
      final b = Float64List.fromList([2, 2]);
      final joined = VoiceClipService.concatWithGaps([a, b], 100);
      final gap = (100 * VoiceClipService.gapSeconds).round();
      expect(joined.length, 4 + gap);
      expect(joined.sublist(0, 2), [1, 1]);
      expect(joined.sublist(2, 2 + gap).every((v) => v == 0), isTrue);
      expect(joined.sublist(2 + gap), [2, 2]);
    });
  });

  group('VoiceClipService file round-trip', () {
    late Directory tmp;
    late VoiceClipService service;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('voxna_clips_');
      service = VoiceClipService(documentsDirectory: () async => tmp);
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('saveClip writes a 3-second 22050Hz clip and buildCollage joins them',
        () async {
      // Two 30-second mono 44.1kHz sources
      for (final id in ['a', 'b']) {
        final src = '${tmp.path}/src_$id.wav';
        await Wav([_sine(44100, 30)], 44100).writeFile(src);
        final path = await service.saveClip(
          sourceWavPath: src,
          recordingId: id,
        );
        expect(path, isNotNull);
        final clip = await Wav.readFile(path!);
        expect(clip.samplesPerSecond, 22050);
        expect(clip.channels[0].length, 22050 * VoiceClipService.clipSeconds);
      }
      expect(await service.hasClip('a'), isTrue);
      expect(await service.hasClip('missing'), isFalse);

      final out = '${tmp.path}/collage.wav';
      final result = await service.buildCollage(
        recordingIds: ['a', 'missing', 'b'],
        outputPath: out,
      );
      expect(result, out);
      final collage = await Wav.readFile(out);
      final gap = (22050 * VoiceClipService.gapSeconds).round();
      expect(collage.channels[0].length, 2 * 22050 * 3 + gap);
    });

    test('buildCollage returns null with fewer than two clips', () async {
      final src = '${tmp.path}/src.wav';
      await Wav([_sine(44100, 5)], 44100).writeFile(src);
      await service.saveClip(sourceWavPath: src, recordingId: 'only');
      final result = await service.buildCollage(
        recordingIds: ['only'],
        outputPath: '${tmp.path}/out.wav',
      );
      expect(result, isNull);
    });

    test('saveClip returns null for an unreadable source', () async {
      final result = await service.saveClip(
        sourceWavPath: '${tmp.path}/does_not_exist.wav',
        recordingId: 'x',
      );
      expect(result, isNull);
    });

    test('deleteAll removes the clip directory', () async {
      final src = '${tmp.path}/src.wav';
      await Wav([_sine(44100, 5)], 44100).writeFile(src);
      await service.saveClip(sourceWavPath: src, recordingId: 'd');
      expect(await service.hasClip('d'), isTrue);
      await service.deleteAll();
      expect(await service.hasClip('d'), isFalse);
    });
  });
}
