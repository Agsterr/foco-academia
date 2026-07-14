import 'package:shared_preferences/shared_preferences.dart';

/// Feature flags e versões do pipeline GPS (Fase 3).
class GpsConfig {
  const GpsConfig({
    this.kalmanEnabled = true,
    this.jumpDetectionEnabled = true,
    this.confidenceEnabled = true,
    this.adaptiveSamplingEnabled = false,
    this.autoPauseEnabled = false,
    this.minAccuracy = 45,
    this.maxSpeed = 40,
    this.minDistance = 2.5,
    this.gpsAlgorithmVersion = '2',
    this.filterVersion = '2',
    this.kalmanVersion = '1',
    this.distanceVersion = '2',
    this.caloriesVersion = '1',
  });

  final bool kalmanEnabled;
  final bool jumpDetectionEnabled;
  final bool confidenceEnabled;
  final bool adaptiveSamplingEnabled;
  final bool autoPauseEnabled;
  final double minAccuracy;
  final double maxSpeed;
  final double minDistance;

  final String gpsAlgorithmVersion;
  final String filterVersion;
  final String kalmanVersion;
  final String distanceVersion;
  final String caloriesVersion;

  static const defaults = GpsConfig();

  GpsConfig copyWith({
    bool? kalmanEnabled,
    bool? jumpDetectionEnabled,
    bool? confidenceEnabled,
    bool? adaptiveSamplingEnabled,
    bool? autoPauseEnabled,
    double? minAccuracy,
    double? maxSpeed,
    double? minDistance,
  }) {
    return GpsConfig(
      kalmanEnabled: kalmanEnabled ?? this.kalmanEnabled,
      jumpDetectionEnabled: jumpDetectionEnabled ?? this.jumpDetectionEnabled,
      confidenceEnabled: confidenceEnabled ?? this.confidenceEnabled,
      adaptiveSamplingEnabled:
          adaptiveSamplingEnabled ?? this.adaptiveSamplingEnabled,
      autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
      minAccuracy: minAccuracy ?? this.minAccuracy,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      minDistance: minDistance ?? this.minDistance,
      gpsAlgorithmVersion: gpsAlgorithmVersion,
      filterVersion: filterVersion,
      kalmanVersion: kalmanVersion,
      distanceVersion: distanceVersion,
      caloriesVersion: caloriesVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'kalmanEnabled': kalmanEnabled,
        'jumpDetectionEnabled': jumpDetectionEnabled,
        'confidenceEnabled': confidenceEnabled,
        'adaptiveSamplingEnabled': adaptiveSamplingEnabled,
        'autoPauseEnabled': autoPauseEnabled,
        'minAccuracy': minAccuracy,
        'maxSpeed': maxSpeed,
        'minDistance': minDistance,
        'gpsAlgorithmVersion': gpsAlgorithmVersion,
        'filterVersion': filterVersion,
        'kalmanVersion': kalmanVersion,
        'distanceVersion': distanceVersion,
        'caloriesVersion': caloriesVersion,
      };

  factory GpsConfig.fromJson(Map<String, dynamic> json) => GpsConfig(
        kalmanEnabled: json['kalmanEnabled'] as bool? ?? true,
        jumpDetectionEnabled: json['jumpDetectionEnabled'] as bool? ?? true,
        confidenceEnabled: json['confidenceEnabled'] as bool? ?? true,
        adaptiveSamplingEnabled:
            json['adaptiveSamplingEnabled'] as bool? ?? false,
        autoPauseEnabled: json['autoPauseEnabled'] as bool? ?? false,
        minAccuracy: (json['minAccuracy'] as num?)?.toDouble() ?? 45,
        maxSpeed: (json['maxSpeed'] as num?)?.toDouble() ?? 40,
        minDistance: (json['minDistance'] as num?)?.toDouble() ?? 2.5,
        gpsAlgorithmVersion: json['gpsAlgorithmVersion'] as String? ?? '2',
        filterVersion: json['filterVersion'] as String? ?? '2',
        kalmanVersion: json['kalmanVersion'] as String? ?? '1',
        distanceVersion: json['distanceVersion'] as String? ?? '2',
        caloriesVersion: json['caloriesVersion'] as String? ?? '1',
      );

  Map<String, String> versionSnapshot() => {
        'gpsAlgorithmVersion': gpsAlgorithmVersion,
        'filterVersion': filterVersion,
        'kalmanVersion': kalmanVersion,
        'distanceVersion': distanceVersion,
        'caloriesVersion': caloriesVersion,
      };
}

/// Persistência local de overrides de GpsConfig.
class GpsConfigStore {
  GpsConfigStore._();
  static final instance = GpsConfigStore._();

  static const _key = 'gps_config_v1';

  GpsConfig _cached = GpsConfig.defaults;

  GpsConfig get current => _cached;

  Future<GpsConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cached = GpsConfig.defaults;
      return _cached;
    }
    try {
      // SharedPreferences stores JSON string via toString of map — use simple keys.
      final map = <String, dynamic>{};
      for (final part in raw.split('|')) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        final k = kv[0];
        final v = kv[1];
        if (v == 'true' || v == 'false') {
          map[k] = v == 'true';
        } else {
          final n = double.tryParse(v);
          map[k] = n ?? v;
        }
      }
      _cached = GpsConfig.fromJson({...GpsConfig.defaults.toJson(), ...map});
    } catch (_) {
      _cached = GpsConfig.defaults;
    }
    return _cached;
  }

  Future<void> save(GpsConfig config) async {
    _cached = config;
    final prefs = await SharedPreferences.getInstance();
    final flat = config.toJson().entries.map((e) => '${e.key}=${e.value}').join('|');
    await prefs.setString(_key, flat);
  }

  Future<GpsConfig> applyRemote(Map<String, dynamic> remote) async {
    final merged = GpsConfig.fromJson({
      ..._cached.toJson(),
      ...remote,
      // Versões do app prevalecem (código local).
      'gpsAlgorithmVersion': GpsConfig.defaults.gpsAlgorithmVersion,
      'filterVersion': GpsConfig.defaults.filterVersion,
      'kalmanVersion': GpsConfig.defaults.kalmanVersion,
      'distanceVersion': GpsConfig.defaults.distanceVersion,
      'caloriesVersion': GpsConfig.defaults.caloriesVersion,
    });
    await save(merged);
    return merged;
  }
}
