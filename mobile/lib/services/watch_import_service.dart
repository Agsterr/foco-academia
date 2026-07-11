import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import 'auth_service.dart';
import 'gps_tracking_engine.dart';
import 'sync_service.dart';

/// Importa treinos exportados de relógios (GPX / TCX) para a conta do aluno.
class WatchImportService {
  WatchImportService._();
  static final instance = WatchImportService._();

  Future<String> pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gpx', 'tcx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('Nenhum arquivo selecionado');
    }
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) throw Exception('Não foi possível ler o arquivo');
    final content = String.fromCharCodes(bytes);
    final name = (file.name).toLowerCase();

    late final List<TrackedPoint> points;
    late final DateTime startedAt;
    late final double distanceMeters;
    late final int elapsedSec;

    if (name.endsWith('.tcx')) {
      final parsed = _parseTcx(content);
      points = parsed.points;
      startedAt = parsed.startedAt;
      distanceMeters = parsed.distanceMeters;
      elapsedSec = parsed.elapsedSec;
    } else {
      final parsed = _parseGpx(content);
      points = parsed.points;
      startedAt = parsed.startedAt;
      distanceMeters = parsed.distanceMeters;
      elapsedSec = parsed.elapsedSec;
    }

    if (points.length < 2) {
      throw Exception('Arquivo sem pontos de rota suficientes');
    }

    final avgSpeed =
        elapsedSec > 0 ? (distanceMeters / 1000) / (elapsedSec / 3600) : 0.0;
    final payload = {
      'clientSessionId': const Uuid().v4(),
      'startedAt': startedAt.toUtc().toIso8601String(),
      'completedAt':
          startedAt.add(Duration(seconds: elapsedSec)).toUtc().toIso8601String(),
      'distanceMeters': distanceMeters,
      'avgSpeedKmh': avgSpeed,
      'elapsedMs': elapsedSec * 1000,
      'points': points.map((p) => p.toJson()).toList(),
      'source': 'WATCH',
    };

    try {
      await AuthService.instance.post('/api/student/sync', {
        'measurements': [],
        'cardioSessions': [payload],
      });
    } catch (_) {
      await SyncService.instance.queue('cardio_session', payload);
      return 'Treino importado e salvo offline — sincronize depois '
          '(${(distanceMeters / 1000).toStringAsFixed(2)} km)';
    }
    return 'Treino do relógio importado: '
        '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  _ParsedTrack _parseGpx(String xml) {
    final doc = XmlDocument.parse(xml);
    final trkpts = doc.findAllElements('trkpt').toList();
    final points = <TrackedPoint>[];
    var seq = 0;
    for (final pt in trkpts) {
      final lat = double.tryParse(pt.getAttribute('lat') ?? '');
      final lon = double.tryParse(pt.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;
      final timeEls = pt.findElements('time');
      final eleEls = pt.findElements('ele');
      final time = timeEls.isNotEmpty
          ? DateTime.tryParse(timeEls.first.innerText) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();
      final ele =
          eleEls.isNotEmpty ? double.tryParse(eleEls.first.innerText) : null;
      points.add(
        TrackedPoint(
          latitude: lat,
          longitude: lon,
          altitudeMeters: ele,
          recordedAt: time.toUtc(),
          sequenceNum: seq++,
          activity: MotionActivity.run,
        ),
      );
    }
    return _fromPoints(points);
  }

  _ParsedTrack _parseTcx(String xml) {
    final doc = XmlDocument.parse(xml);
    final trackpoints = doc.findAllElements('Trackpoint').toList();
    final points = <TrackedPoint>[];
    var seq = 0;
    for (final tp in trackpoints) {
      final latEls = tp.findAllElements('LatitudeDegrees');
      final lonEls = tp.findAllElements('LongitudeDegrees');
      if (latEls.isEmpty || lonEls.isEmpty) continue;
      final lat = double.tryParse(latEls.first.innerText);
      final lon = double.tryParse(lonEls.first.innerText);
      if (lat == null || lon == null) continue;
      final timeEls = tp.findElements('Time');
      final eleEls = tp.findElements('AltitudeMeters');
      final time = timeEls.isNotEmpty
          ? DateTime.tryParse(timeEls.first.innerText) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();
      points.add(
        TrackedPoint(
          latitude: lat,
          longitude: lon,
          altitudeMeters: eleEls.isNotEmpty
              ? double.tryParse(eleEls.first.innerText)
              : null,
          recordedAt: time.toUtc(),
          sequenceNum: seq++,
          activity: MotionActivity.run,
        ),
      );
    }
    return _fromPoints(points);
  }

  _ParsedTrack _fromPoints(List<TrackedPoint> points) {
    if (points.isEmpty) {
      return _ParsedTrack(
        points: const [],
        startedAt: DateTime.now().toUtc(),
        distanceMeters: 0,
        elapsedSec: 0,
      );
    }
    var dist = 0.0;
    for (var i = 1; i < points.length; i++) {
      dist += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    final started = points.first.recordedAt;
    final ended = points.last.recordedAt;
    final elapsed = ended.difference(started).inSeconds.clamp(0, 86400 * 7);
    return _ParsedTrack(
      points: points,
      startedAt: started,
      distanceMeters: dist,
      elapsedSec: elapsed,
    );
  }
}

class _ParsedTrack {
  const _ParsedTrack({
    required this.points,
    required this.startedAt,
    required this.distanceMeters,
    required this.elapsedSec,
  });

  final List<TrackedPoint> points;
  final DateTime startedAt;
  final double distanceMeters;
  final int elapsedSec;
}
