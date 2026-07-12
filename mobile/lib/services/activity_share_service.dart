import 'package:share_plus/share_plus.dart';

import 'cardio_service.dart';
import 'gps_tracking_engine.dart';

/// Compartilha resumo textual da atividade (além de GPX/TCX).
class ActivityShareService {
  ActivityShareService._();
  static final instance = ActivityShareService._();

  Future<void> shareSummary({
    required String title,
    required double distanceMeters,
    required int elapsedMs,
    double? avgSpeedKmh,
    int? caloriesKcal,
    double? gpsQualityScore,
    String? gpsQualityLabel,
    DateTime? completedAt,
  }) async {
    final km = (distanceMeters / 1000).toStringAsFixed(2);
    final pace = GpsTrackingEngine.formatPace(
      distanceMeters >= 30 && elapsedMs >= 10000
          ? (elapsedMs / 1000.0) / (distanceMeters / 1000.0)
          : null,
    );
    final elapsed = _fmt((elapsedMs / 1000).round());
    final buf = StringBuffer()
      ..writeln('🏃 $title — Foco Academia')
      ..writeln('Distância: $km km')
      ..writeln('Tempo: $elapsed')
      ..writeln('Ritmo médio: $pace');
    if (avgSpeedKmh != null) {
      buf.writeln('Velocidade: ${avgSpeedKmh.toStringAsFixed(1)} km/h');
    }
    if (caloriesKcal != null) {
      buf.writeln('Calorias: $caloriesKcal kcal');
    }
    if (gpsQualityLabel != null) {
      final q = gpsQualityScore != null
          ? '${gpsQualityScore.round()}% · $gpsQualityLabel'
          : gpsQualityLabel;
      buf.writeln('GPS: $q');
    }
    if (completedAt != null) {
      buf.writeln('Data: ${completedAt.toLocal()}');
    }
    await SharePlus.instance.share(ShareParams(text: buf.toString()));
  }

  Future<void> shareSession(CardioSession session) {
    return shareSummary(
      title: session.workoutTitle ?? 'Treino outdoor',
      distanceMeters: session.distanceMeters ?? 0,
      elapsedMs: session.elapsedMs ?? 0,
      avgSpeedKmh: session.avgSpeedKmh,
      caloriesKcal: session.caloriesKcal,
      gpsQualityScore: session.gpsQualityScore,
      gpsQualityLabel: session.gpsQualityLabel,
      completedAt: session.completedAt,
    );
  }

  static String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
