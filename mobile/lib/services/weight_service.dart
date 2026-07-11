import 'auth_service.dart';

class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
    required this.source,
    this.notes,
  });

  final String id;
  final double weightKg;
  final String recordedAt;
  final String source;
  final String? notes;

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: json['id'] as String,
      weightKg: (json['weightKg'] as num).toDouble(),
      recordedAt: json['recordedAt'] as String? ?? '',
      source: json['source'] as String? ?? 'STUDENT',
      notes: json['notes'] as String?,
    );
  }
}

class WeightService {
  WeightService._();
  static final instance = WeightService._();

  Future<List<BodyMeasurement>> list() async {
    final list = await AuthService.instance.getList('/api/student/measurements');
    return list
        .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BodyMeasurement> add({
    required double weightKg,
    String? notes,
    String source = 'STUDENT',
  }) async {
    final data = await AuthService.instance.post('/api/student/measurements', {
      'weightKg': weightKg,
      if (notes != null) 'notes': notes,
      'source': source,
    });
    return BodyMeasurement.fromJson(data);
  }
}
