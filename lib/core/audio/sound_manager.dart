import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';

enum SoundId {
  theta('snd_01_theta.ogg'),
  ambient('snd_02_ambient.ogg'),
  bowlStrike('snd_03_bowl_strike.ogg'),
  breath('snd_04_breath.ogg'),
  bowlSustain('snd_05_bowl_sustain.ogg'),
  ambientLoop('snd_06_ambient_loop.ogg'),
  click('snd_07_click.aac'),
  drop('snd_08_drop.aac'),
  breathe('snd_09_breathe.ogg');

  final String fileName;
  const SoundId(this.fileName);
}

class SoundManager {
  final Map<SoundId, AudioPlayer> _players = {};
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool value) => _enabled = value;

  Future<void> play(SoundId sound, {bool loop = false}) async {
    if (!_enabled) return;

    try {
      final player = _players[sound] ?? AudioPlayer();
      _players[sound] = player;

      if (loop) {
        await player.setReleaseMode(ReleaseMode.loop);
      } else {
        await player.setReleaseMode(ReleaseMode.release);
      }

      await player.play(AssetSource('sounds/${sound.fileName}'));
    } catch (e) {
      developer.log(
        'Failed to play sound: ${sound.fileName}',
        name: 'SoundManager',
        error: e,
      );
    }
  }

  Future<void> stop(SoundId sound) async {
    try {
      await _players[sound]?.stop();
    } catch (e) {
      developer.log(
        'Failed to stop sound: ${sound.fileName}',
        name: 'SoundManager',
        error: e,
      );
    }
  }

  Future<void> stopAll() async {
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
