import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

/// Feedback sonoro/tátil para troca de fase no outdoor.
/// Caminhada = 1 vibração longa + voz "Caminhada" + 1 bipe grave.
/// Corrida = 2 vibrações espaçadas + voz "Corrida" + 2 bipes agudos.
/// Áudio usa rota de mídia (fone quando conectado) e só abaixa a música.
class CardioFeedback {
  CardioFeedback._();

  /// [pausa, vibrar, pausa, vibrar, ...] em milissegundos.
  static const List<int> walkVibrationPattern = [0, 550];
  static const List<int> runVibrationPattern = [0, 500, 550, 500];

  static final AudioPlayer _player = AudioPlayer();
  static final FlutterTts _tts = FlutterTts();
  static bool _playerReady = false;
  static bool _ttsReady = false;

  static String phaseSpeechLabel(String phase) =>
      phase.toUpperCase() == 'RUN' ? 'Corrida' : 'Caminhada';

  static List<int> phaseVibrationPattern(String phase) =>
      phase.toUpperCase() == 'RUN' ? runVibrationPattern : walkVibrationPattern;

  static Future<void> _ensurePlayer() async {
    if (_playerReady) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1);
    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          // false = segue a rota atual (fone BT/cabo); true força alto-falante.
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          // media (não alarm/navigation): bipe no mesmo caminho da música/fone.
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.duckOthers,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    );
    _playerReady = true;
  }

  static Future<void> _ensureTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    await _tts.awaitSpeakCompletion(true);
    // Não usar setAudioAttributesForNavigation(): no Android isso manda a voz
    // para o alto-falante do aparelho enquanto a música continua no fone.
    // Sem isso, o TTS usa a rota de mídia (fone quando conectado).
    if (Platform.isIOS) {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
    _ttsReady = true;
  }

  /// Gera WAV PCM 16-bit mono com um bipe audível.
  static Uint8List _beepWav({required int frequencyHz, int durationMs = 320}) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2;
    final header = ByteData(44);
    final pcm = ByteData(dataSize);

    void u32(int offset, int v) => header.setUint32(offset, v, Endian.little);
    void u16(int offset, int v) => header.setUint16(offset, v, Endian.little);

    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    u32(4, 36 + dataSize);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6d);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    u32(16, 16);
    u16(20, 1);
    u16(22, 1);
    u32(24, sampleRate);
    u32(28, sampleRate * 2);
    u16(32, 2);
    u16(34, 16);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    u32(40, dataSize);

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final env = i < 250
          ? i / 250
          : (i > numSamples - 500 ? math.max(0, (numSamples - i) / 500) : 1.0);
      final sample = (math.sin(2 * math.pi * frequencyHz * t) * 0.55 * env * 32767)
          .round()
          .clamp(-32768, 32767);
      pcm.setInt16(i * 2, sample, Endian.little);
    }

    final out = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm.buffer.asUint8List());
    return out.toBytes();
  }

  static Future<void> _playTone(int frequencyHz, {int durationMs = 320}) async {
    try {
      await _ensurePlayer();
      final wav = _beepWav(frequencyHz: frequencyHz, durationMs: durationMs);
      await _player.stop();
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
      await Future<void>.delayed(Duration(milliseconds: durationMs + 80));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  static Future<void> _speak(String text) async {
    try {
      await _ensureTts();
      await _tts.stop();
      // focus:true no Android pede AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK:
      // a música abaixa durante a fala e volta depois (não para).
      await _tts.speak(text, focus: true);
    } catch (_) {}
  }

  static Future<void> _vibratePattern(List<int> pattern) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        final hasCustom = await Vibration.hasCustomVibrationsSupport();
        if (hasCustom == true) {
          await Vibration.vibrate(pattern: pattern);
          return;
        }
        for (var i = 1; i < pattern.length; i += 2) {
          if (pattern[i - 1] > 0) {
            await Future<void>.delayed(Duration(milliseconds: pattern[i - 1]));
          }
          await Vibration.vibrate(duration: pattern[i].clamp(300, 900));
        }
        return;
      }
    } catch (_) {}

    final pulses = pattern.length ~/ 2;
    for (var p = 0; p < pulses; p++) {
      if (p > 0) {
        final gapIndex = p * 2 - 1;
        final gapMs = gapIndex < pattern.length ? pattern[gapIndex] : 500;
        await Future<void>.delayed(Duration(milliseconds: gapMs));
      }
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  static Future<void> _playPhaseTones(bool isRun) async {
    if (isRun) {
      await _playTone(1100, durationMs: 340);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _playTone(1100, durationMs: 340);
    } else {
      await _playTone(650, durationMs: 420);
    }
  }

  /// [count] bipes genéricos (ex.: início / fim).
  static Future<void> playBeeps(int count) async {
    final n = count.clamp(1, 5);
    for (var i = 0; i < n; i++) {
      await Future.wait([
        _playTone(880, durationMs: 300),
        _vibratePattern([0, 400]),
      ]);
      if (i < n - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
      }
    }
  }

  /// Troca de fase: vibração longa e espaçada, depois voz + bipes sobre a música.
  static Future<void> playPhase(String phase) async {
    final isRun = phase.toUpperCase() == 'RUN';
    final label = phaseSpeechLabel(phase);
    final pattern = phaseVibrationPattern(phase);

    await _vibratePattern(pattern);
    await Future<void>.delayed(Duration(milliseconds: isRun ? 450 : 350));
    await Future.wait([
      _speak(label),
      _playPhaseTones(isRun),
    ]);
  }

  static Future<void> playFinish() async {
    await _speak('Treino concluído');
    await playBeeps(3);
    await _vibratePattern([0, 450, 400, 450]);
  }
}
