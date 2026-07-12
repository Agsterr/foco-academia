import 'filter_reason.dart';
import 'gps_tracking_engine.dart';

class GpsQualityResult {
  const GpsQualityResult({
    required this.score,
    required this.label,
    required this.avgAccuracyMeters,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.jumpCount,
    required this.gpsGapSec,
  });

  /// 0–100
  final double score;
  final String label;
  final double avgAccuracyMeters;
  final int acceptedCount;
  final int rejectedCount;
  final int jumpCount;
  final int gpsGapSec;

  String get display => '${score.round()}% · $label';
}

/// Nota geral de qualidade GPS da sessão.
class GpsQualityService {
  GpsQualityService._();
  static final instance = GpsQualityService._();

  GpsQualityResult evaluate({
    required List<TrackedPoint> acceptedPoints,
    required Map<FilterReason, int> rejectCounts,
    required int gpsGapSec,
  }) {
    final accepted = acceptedPoints.length;
    final rejected = rejectCounts.values.fold<int>(0, (a, b) => a + b);
    final jumps = rejectCounts[FilterReason.gpsJump] ?? 0;
    final total = accepted + rejected;

    double avgAcc = 25;
    double avgConf = 0.7;
    if (acceptedPoints.isNotEmpty) {
      var sumAcc = 0.0;
      var sumConf = 0.0;
      var nAcc = 0;
      for (final p in acceptedPoints) {
        if (p.accuracyMeters != null) {
          sumAcc += p.accuracyMeters!;
          nAcc++;
        }
        sumConf += p.confidenceScore ?? 0.7;
      }
      if (nAcc > 0) avgAcc = sumAcc / nAcc;
      avgConf = sumConf / acceptedPoints.length;
    }

    // Componentes 0–1
    final accuracyPart = (1.0 / (1.0 + (avgAcc / 18.0))).clamp(0.0, 1.0);
    final rejectRatio = total == 0 ? 0.0 : rejected / total;
    final rejectPart = (1.0 - rejectRatio * 1.4).clamp(0.0, 1.0);
    final jumpPart = (1.0 - (jumps / 10.0)).clamp(0.0, 1.0);
    final gapPart = (1.0 - (gpsGapSec / 180.0)).clamp(0.0, 1.0);
    final confPart = avgConf.clamp(0.0, 1.0);

    final score01 = (accuracyPart * 0.30) +
        (rejectPart * 0.20) +
        (jumpPart * 0.15) +
        (gapPart * 0.15) +
        (confPart * 0.20);

    final score = (score01 * 100).clamp(0.0, 100.0);
    return GpsQualityResult(
      score: score,
      label: _label(score),
      avgAccuracyMeters: avgAcc,
      acceptedCount: accepted,
      rejectedCount: rejected,
      jumpCount: jumps,
      gpsGapSec: gpsGapSec,
    );
  }

  static String _label(double score) {
    if (score >= 90) return 'Excelente';
    if (score >= 75) return 'Boa';
    if (score >= 55) return 'Razoável';
    return 'Baixa precisão';
  }
}
