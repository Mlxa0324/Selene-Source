import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/version_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // 为每个用例重置本地偏好，避免上次提示记录干扰断言。
    SharedPreferences.setMockInitialValues({});
  });

  test('update prompt stays disabled after feature shutdown', () async {
    expect(VersionService.isUpdateCheckEnabled, isFalse);
    expect(await VersionService.shouldShowUpdatePrompt('2.1.8'), isFalse);
  });
}
