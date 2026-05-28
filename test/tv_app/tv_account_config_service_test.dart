import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_account_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saveCredentials exits local mode and writes shared account storage',
      () async {
    SharedPreferences.setMockInitialValues({
      'is_local_mode': true,
      'server_url': 'https://old.example.com',
      'username': 'old_user',
      'password': 'old_password',
      'cookies': 'legacy_cookie=value',
    });

    final service = TvAccountConfigService();
    final result = await service.saveCredentials(
      const TvServerCredentials(
        serverUrl: 'https://server.example.com/',
        username: 'demo_user',
        password: 'demo_password',
      ),
    );

    final savedUserData = await UserDataService.getAllUserData();

    expect(result.success, isTrue);
    expect(savedUserData['serverUrl'], 'https://server.example.com');
    expect(savedUserData['username'], 'demo_user');
    expect(savedUserData['password'], 'demo_password');
    // 切换成新的服务器账号后，旧 cookies 不能继续沿用。
    expect(savedUserData['cookies'], isEmpty);
    // 仅保存服务器配置后，应用也应该退出本地模式，后续链路才能真正吃到这份配置。
    expect(await UserDataService.getIsLocalMode(), isFalse);
  });
}
