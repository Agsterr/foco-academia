import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/data/services/app_update_service.dart';

void main() {
  test('apkFileName inclui versionCode', () {
    expect(AppUpdateService.apkFileName(3), 'foco-academia-update-3.apk');
  });

  test('loginAppVersion retorna valor configurado', () {
    expect(AppUpdateService.loginAppVersion(), matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')));
  });
}
