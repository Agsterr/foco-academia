import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'gps_tracking_engine.dart';

/// Gera e compartilha arquivos GPX / TCX da corrida.
class RunExportService {
  RunExportService._();
  static final instance = RunExportService._();

  Future<void> shareGpx({
    required List<TrackedPoint> points,
    required String title,
    DateTime? startedAt,
    double? distanceMeters,
    double? elevationGainMeters,
  }) async {
    final xml = buildGpx(
      points: points,
      title: title,
      startedAt: startedAt,
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
    );
    await _shareFile(xml, 'foco-academia-${_stamp()}.gpx', 'application/gpx+xml');
  }

  Future<void> shareTcx({
    required List<TrackedPoint> points,
    required String title,
    required DateTime startedAt,
    required int elapsedSec,
    required double distanceMeters,
    double elevationGainMeters = 0,
  }) async {
    final xml = buildTcx(
      points: points,
      title: title,
      startedAt: startedAt,
      elapsedSec: elapsedSec,
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
    );
    await _shareFile(
      xml,
      'foco-academia-${_stamp()}.tcx',
      'application/vnd.garmin.tcx+xml',
    );
  }

  String buildGpx({
    required List<TrackedPoint> points,
    required String title,
    DateTime? startedAt,
    double? distanceMeters,
    double? elevationGainMeters,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<gpx version="1.1" creator="Foco Academia" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    );
    buffer.writeln('<metadata>');
    buffer.writeln('<name>${_esc(title)}</name>');
    if (startedAt != null) {
      buffer.writeln('<time>${startedAt.toUtc().toIso8601String()}</time>');
    }
    buffer.writeln('</metadata>');
    buffer.writeln('<trk>');
    buffer.writeln('<name>${_esc(title)}</name>');
    if (distanceMeters != null || elevationGainMeters != null) {
      buffer.writeln('<desc>');
      if (distanceMeters != null) {
        buffer.write(
          'Distância: ${(distanceMeters / 1000).toStringAsFixed(2)} km. ',
        );
      }
      if (elevationGainMeters != null) {
        buffer.write(
          'Ganho elevação: ${elevationGainMeters.toStringAsFixed(0)} m.',
        );
      }
      buffer.writeln('</desc>');
    }
    buffer.writeln('<trkseg>');
    for (final p in points) {
      buffer.write('<trkpt lat="${p.latitude}" lon="${p.longitude}">');
      if (p.altitudeMeters != null) {
        buffer.write('<ele>${p.altitudeMeters!.toStringAsFixed(1)}</ele>');
      }
      buffer.write('<time>${p.recordedAt.toUtc().toIso8601String()}</time>');
      buffer.writeln('</trkpt>');
    }
    buffer.writeln('</trkseg>');
    buffer.writeln('</trk>');
    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  String buildTcx({
    required List<TrackedPoint> points,
    required String title,
    required DateTime startedAt,
    required int elapsedSec,
    required double distanceMeters,
    double elevationGainMeters = 0,
  }) {
    final sport = _dominantSport(points);
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<TrainingCenterDatabase '
      'xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">',
    );
    buffer.writeln('<Activities>');
    buffer.writeln('<Activity Sport="$sport">');
    buffer.writeln('<Id>${startedAt.toUtc().toIso8601String()}</Id>');
    buffer.writeln('<Lap StartTime="${startedAt.toUtc().toIso8601String()}">');
    buffer.writeln('<TotalTimeSeconds>$elapsedSec</TotalTimeSeconds>');
    buffer.writeln(
      '<DistanceMeters>${distanceMeters.toStringAsFixed(1)}</DistanceMeters>',
    );
    final maxAlt = _maxAltitude(points);
    if (maxAlt != null) {
      buffer.writeln(
        '<MaximumAltitudeMeters>${maxAlt.toStringAsFixed(1)}</MaximumAltitudeMeters>',
      );
    }
    buffer.writeln('<Intensity>Active</Intensity>');
    buffer.writeln('<TriggerMethod>Manual</TriggerMethod>');
    buffer.writeln('<Track>');
    var dist = 0.0;
    TrackedPoint? prev;
    for (final p in points) {
      if (prev != null) {
        dist += _haversineMeters(prev, p);
      }
      buffer.writeln('<Trackpoint>');
      buffer.writeln('<Time>${p.recordedAt.toUtc().toIso8601String()}</Time>');
      buffer.writeln('<Position>');
      buffer.writeln('<LatitudeDegrees>${p.latitude}</LatitudeDegrees>');
      buffer.writeln('<LongitudeDegrees>${p.longitude}</LongitudeDegrees>');
      buffer.writeln('</Position>');
      if (p.altitudeMeters != null) {
        buffer.writeln(
          '<AltitudeMeters>${p.altitudeMeters!.toStringAsFixed(1)}</AltitudeMeters>',
        );
      }
      buffer.writeln('<DistanceMeters>${dist.toStringAsFixed(1)}</DistanceMeters>');
      if (p.speedKmh != null) {
        buffer.writeln(
          '<Extensions><TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">'
          '<Speed>${(p.speedKmh! / 3.6).toStringAsFixed(3)}</Speed>'
          '</TPX></Extensions>',
        );
      }
      buffer.writeln('</Trackpoint>');
      prev = p;
    }
    buffer.writeln('</Track>');
    buffer.writeln('</Lap>');
    buffer.writeln('<Notes>${_esc(title)}</Notes>');
    buffer.writeln('</Activity>');
    buffer.writeln('</Activities>');
    buffer.writeln('</TrainingCenterDatabase>');
    return buffer.toString();
  }

  Future<void> _shareFile(String content, String filename, String mime) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime, name: filename)],
        subject: 'Treino outdoor — Foco Academia',
        text: 'Exportação do treino outdoor',
      ),
    );
  }

  String _stamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}-'
        '${n.hour.toString().padLeft(2, '0')}'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  String _esc(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _dominantSport(List<TrackedPoint> points) {
    var run = 0;
    var walk = 0;
    for (final p in points) {
      if (p.activity == MotionActivity.run) run++;
      if (p.activity == MotionActivity.walk) walk++;
    }
    return run >= walk ? 'Running' : 'Walking';
  }

  double? _maxAltitude(List<TrackedPoint> points) {
    double? max;
    for (final p in points) {
      final a = p.altitudeMeters;
      if (a == null) continue;
      if (max == null || a > max) max = a;
    }
    return max;
  }

  double _haversineMeters(TrackedPoint a, TrackedPoint b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double d) => d * math.pi / 180.0;
}
