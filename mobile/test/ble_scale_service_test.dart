import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/ble_scale_service.dart';

void main() {
  test('parse OKOK formato C0 (81.50 kg estável)', () {
    final bytes = [
      0xc0, 0xb1, 0x1f, 0xd6, 0x17, 0x70, 0x0a, 0x01, 0x25,
      0x5d, 0x02, 0x49, 0xa6, 0x3d, 0xe8, 0xae,
    ];
    final parsed = BleScaleService.parseOkokManufacturerBytes(bytes);
    expect(parsed, isNotNull);
    expect(parsed!.kg, closeTo(81.5, 0.01));
    expect(parsed.stable, isTrue);
  });

  test('C0 não multiplica por 10 (6.8 e 12.0 kg)', () {
    // 6.80 kg → 680 = 0x02A8
    final light = [
      0xc0, 0xb1, 0x02, 0xa8, 0x17, 0x70, 0x0a, 0x01, 0x25,
      0x5d, 0x02, 0x49, 0xa6, 0x3d, 0xe8, 0xae,
    ];
    final p1 = BleScaleService.parseOkokManufacturerBytes(light);
    expect(p1, isNotNull);
    expect(p1!.kg, closeTo(6.8, 0.01));

    // 12.00 kg → 1200 = 0x04B0
    final mid = [
      0xc0, 0xb1, 0x04, 0xb0, 0x17, 0x70, 0x0a, 0x01, 0x25,
      0x5d, 0x02, 0x49, 0xa6, 0x3d, 0xe8, 0xae,
    ];
    final p2 = BleScaleService.parseOkokManufacturerBytes(mid);
    expect(p2, isNotNull);
    expect(p2!.kg, closeTo(12.0, 0.01));
  });

  test('C0 68.0 kg continua correto', () {
    // 68.00 → 6800 = 0x1A90
    final bytes = [
      0xc0, 0xb1, 0x1a, 0x90, 0x17, 0x70, 0x0a, 0x01, 0x25,
      0x5d, 0x02, 0x49, 0xa6, 0x3d, 0xe8, 0xae,
    ];
    final parsed = BleScaleService.parseOkokManufacturerBytes(bytes);
    expect(parsed, isNotNull);
    expect(parsed!.kg, closeTo(68.0, 0.01));
  });

  test('parse OKOK formato CA (95.0 kg)', () {
    final bytes = [
      0xca, 0x20, 0x0b, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0xeb, 0x03, 0xb6,
      0x13, 0x8a, 0xec,
    ];
    final parsed = BleScaleService.parseOkokManufacturerBytes(bytes);
    expect(parsed, isNotNull);
    expect(parsed!.kg, closeTo(95.0, 0.05));
  });

  test('parse Weight Scale GATT 0x2A9D', () {
    final kg = BleScaleService.parseWeightMeasurement([0x00, 0xB0, 0x36]);
    expect(kg, closeTo(70.0, 0.01));
  });
}
