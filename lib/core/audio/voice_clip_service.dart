import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';

/// Keeps a short clip (the first few seconds) of every recording on the
/// device so that the weekly "voice of the week" collage can be assembled
/// later without retaining the full recordings.
///
/// Clips never leave the device. They live under
/// `<app documents>/voice_clips/<recordingId>.wav`.
class VoiceClipService {
  static const int clipSeconds = 3;
  static const int targetSampleRate = 22050;
  static const int retentionDays = 120;
  static const double gapSeconds = 0.15;
  static const double fadeSeconds = 0.05;

  final Future<Directory> Function() _documentsDirectory;

  VoiceClipService({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<Directory> clipDirectory() async {
    final root = await _documentsDirectory();
    final dir = Directory('${root.path}/voice_clips');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> clipPathFor(String recordingId) async {
    final dir = await clipDirectory();
    return '${dir.path}/$recordingId.wav';
  }

  Future<bool> hasClip(String recordingId) async {
    return File(await clipPathFor(recordingId)).exists();
  }

  /// Extracts the first [clipSeconds] of [sourceWavPath] and stores it as a
  /// mono 16-bit WAV. Returns the clip path, or null if the source could not
  /// be read.
  Future<String?> saveClip({
    required String sourceWavPath,
    required String recordingId,
  }) async {
    final Wav wav;
    try {
      wav = await Wav.readFile(sourceWavPath);
    } catch (_) {
      return null;
    }
    if (wav.channels.isEmpty || wav.channels[0].isEmpty) return null;

    var samples = extractClip(wav.channels[0], wav.samplesPerSecond);
    var rate = wav.samplesPerSecond;
    final down = downsample(samples, rate, targetSampleRate);
    samples = down.samples;
    rate = down.sampleRate;
    samples = applyFades(samples, rate);

    final path = await clipPathFor(recordingId);
    try {
      await Wav([samples], rate, WavFormat.pcm16bit).writeFile(path);
    } catch (_) {
      return null;
    }
    return path;
  }

  /// Joins the clips of [recordingIds] (in the given order) into one WAV at
  /// [outputPath], separated by short silences. Returns the output path, or
  /// null when fewer than [minimumClips] clips exist.
  Future<String?> buildCollage({
    required List<String> recordingIds,
    required String outputPath,
    int minimumClips = 2,
  }) async {
    final parts = <Float64List>[];
    int? rate;
    for (final id in recordingIds) {
      final file = File(await clipPathFor(id));
      if (!await file.exists()) continue;
      final Wav wav;
      try {
        wav = await Wav.readFile(file.path);
      } catch (_) {
        continue;
      }
      if (wav.channels.isEmpty || wav.channels[0].isEmpty) continue;
      if (rate != null && wav.samplesPerSecond != rate) {
        // Mixed sample rates are not expected; skip to keep the output valid.
        continue;
      }
      rate = wav.samplesPerSecond;
      parts.add(wav.channels[0]);
    }
    if (rate == null || parts.length < minimumClips) return null;

    final joined = concatWithGaps(parts, rate);
    try {
      await Wav([joined], rate, WavFormat.pcm16bit).writeFile(outputPath);
    } catch (_) {
      return null;
    }
    return outputPath;
  }

  /// Removes clips older than [days] (by file modification time).
  Future<int> prune({int days = retentionDays}) async {
    final dir = await clipDirectory();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
          removed++;
        }
      } catch (_) {
        // Ignore files that vanish or cannot be read.
      }
    }
    return removed;
  }

  Future<void> deleteAll() async {
    final dir = await clipDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // ---- pure helpers (unit tested) ----

  /// First [seconds] seconds of [samples]; shorter input is returned as-is.
  static Float64List extractClip(
    Float64List samples,
    int sampleRate, {
    int seconds = clipSeconds,
  }) {
    final count = min(samples.length, sampleRate * seconds);
    return Float64List.fromList(samples.sublist(0, count));
  }

  /// Integer-factor decimation with box averaging. When [from] is not a
  /// multiple of [to], the samples are returned unchanged at [from].
  static ({Float64List samples, int sampleRate}) downsample(
    Float64List samples,
    int from,
    int to,
  ) {
    if (from <= to || from % to != 0) {
      return (samples: samples, sampleRate: from);
    }
    final factor = from ~/ to;
    final outLength = samples.length ~/ factor;
    final out = Float64List(outLength);
    for (var i = 0; i < outLength; i++) {
      var sum = 0.0;
      final base = i * factor;
      for (var k = 0; k < factor; k++) {
        sum += samples[base + k];
      }
      out[i] = sum / factor;
    }
    return (samples: out, sampleRate: to);
  }

  /// Linear fade-in and fade-out of [fadeSeconds] to avoid clicks at joins.
  static Float64List applyFades(Float64List samples, int sampleRate) {
    final out = Float64List.fromList(samples);
    final fade = min((sampleRate * fadeSeconds).round(), out.length ~/ 2);
    for (var i = 0; i < fade; i++) {
      final g = i / fade;
      out[i] *= g;
      out[out.length - 1 - i] *= g;
    }
    return out;
  }

  /// Concatenates [parts] with [gapSeconds] of silence between them.
  static Float64List concatWithGaps(List<Float64List> parts, int sampleRate) {
    final gap = (sampleRate * gapSeconds).round();
    final total = parts.fold<int>(0, (sum, p) => sum + p.length) +
        gap * max(parts.length - 1, 0);
    final out = Float64List(total);
    var offset = 0;
    for (var i = 0; i < parts.length; i++) {
      out.setRange(offset, offset + parts[i].length, parts[i]);
      offset += parts[i].length;
      if (i < parts.length - 1) offset += gap;
    }
    return out;
  }
}
