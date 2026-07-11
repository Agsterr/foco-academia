import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Feedback sonoro/tátil alinhado ao outdoor web.
/// Corrida = 2 toques; caminhada = 1 toque.
class CardioFeedback {
  CardioFeedback._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _playerReady = false;

  static Future<void> _ensurePlayer() async {
    if (_playerReady) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1);
    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    _playerReady = true;
  }

  /// Gera WAV PCM 16-bit mono com um bipe curto.
  static Uint8List _beepWav({required int frequencyHz, int durationMs = 180}) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2;
    final header = ByteData(44);
    final pcm = ByteData(dataSize);

    void u32(int offset, int v) => header.setUint32(offset, v, Endian.little);
    void u16(int offset, int v) => header.setUint16(offset, v, Endian.little);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    u32(4, 36 + dataSize);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); //
    u32(16, 16);
    u16(20, 1);
    u16(22, 1);
    u32(24, sampleRate);
    u32(28, sampleRate * 2);
    u16(32, 2);
    u16(34, 16);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    u32(40, dataSize);

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final env = i < 200
          ? i / 200
          : (i > numSamples - 400 ? math.max(0, (numSamples - i) / 400) : 1.0);
      final sample =
          (math.sin(2 * math.pi * frequencyHz * t) * 0.45 * env * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, sample, Endian.little);
    }

    final out = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm.buffer.asUint8List());
    return out.toBytes();
  }

  static Future<void> _playTone(int frequencyHz) async {
    try {
      await _ensurePlayer();
      final wav = _beepWav(frequencyHz: frequencyHz);
      await _player.stop();
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static Future<void> _vibratePattern(List<int> pattern) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (await Vibration.hasCustomVibrationsSupport()) {
          await Vibration.vibrate(pattern: pattern);
          return;
        }
        final pulse = pattern.length > 1 ? pattern[1] : 120;
        await Vibration.vibrate(duration: pulse.clamp(50, 600));
        return;
      }
    } catch (_) {}
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// [count] bipes genéricos (ex.: início / fim).
  static Future<void> playBeeps(int count) async {
    final n = count.clamp(1, 5);
    for (var i = 0; i < n; i++) {
      await Future.wait([
        _playTone(880),
        _vibratePattern([0, 120]),
      ]);
      if (i < n - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
      }
    }
  }

  /// Troca de fase: corrida = 2 toques agudos; caminhada = 1 toque grave.
  static Future<void> playPhase(String phase) async {
    final isRun = phase.toUpperCase() == 'RUN';
    if (isRun) {
      // Igual web: vibração [200, pause 100, 200] + 2 bipes agudos.
      await Future.wait([
        () async {
          await _playTone(1200);
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await _playTone(1200);
        }(),
        _vibratePattern([0, 200, 100, 200]),
      ]);
    } else {
      await Future.wait([
        _playTone(600),
        _vibratePattern([0, 100]),
      ]);
    }
  }

  static Future<void> playFinish() async {
    await playBeeps(3);
    await _vibratePattern([0, 250, 80, 250]);
  }
}
