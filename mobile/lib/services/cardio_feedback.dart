import 'package:flutter/services.dart';

/// Feedback sonoro/tátil alinhado ao outdoor web (bipes + vibração).
class CardioFeedback {
  CardioFeedback._();

  static Future<void> playBeeps(int count) async {
    final n = count.clamp(1, 5);
    for (var i = 0; i < n; i++) {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
      if (i < n - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }
    }
  }

  static Future<void> playPhase(String phase) async {
    final isRun = phase.toUpperCase() == 'RUN';
    await SystemSound.play(SystemSoundType.alert);
    if (isRun) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> playFinish() async {
    await playBeeps(3);
    await HapticFeedback.heavyImpact();
  }
}
