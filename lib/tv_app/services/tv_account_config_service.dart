import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:selene/services/user_data_service.dart';

/// TV 端服务器账号配置。
///
/// 用于保存服务器地址、账号和密码，并在 TV 设置页发起登录。
class TvServerCredentials {
  /// 创建 TV 端服务器账号配置。
  const TvServerCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  /// 服务器地址。
  final String serverUrl;

  /// 登录账号。
  final String username;

  /// 登录密码。
  final String password;

  /// 是否具备登录所需字段。
  bool get canLogin =>
      serverUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;
}

/// TV 端账号保存结果。
///
/// [success] 表示登录和保存是否成功，[message] 用于 UI 提示。
class TvAccountSaveResult {
  /// 创建 TV 端账号保存结果。
  const TvAccountSaveResult({
    required this.success,
    required this.message,
  });

  /// 是否保存成功。
  final bool success;

  /// 操作结果提示。
  final String message;
}

/// TV 端服务器账号配置服务。
///
/// 复用现有 `UserDataService` 存储，不为 TV 单独创建账号存储。
class TvAccountConfigService {
  /// 创建 TV 端服务器账号配置服务。
  TvAccountConfigService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// HTTP 客户端。
  final http.Client _client;

  /// 登录请求超时时长。
  static const Duration _timeout = Duration(seconds: 10);

  /// 读取已保存的服务器账号配置。
  Future<TvServerCredentials> loadCredentials() async {
    final userData = await UserDataService.getAllUserData();
    return TvServerCredentials(
      serverUrl: userData['serverUrl'] ?? '',
      username: userData['username'] ?? '',
      password: userData['password'] ?? '',
    );
  }

  /// 仅保存服务器账号配置。
  ///
  /// 当前 TV 首版设置页只保存服务器地址、账号和密码，不立即发起登录。
  /// 若当前激活账号仍是同一组服务器和用户名，则继续沿用已有 cookies；
  /// 否则清空 cookies，避免把旧登录态误绑定到新配置上。
  Future<TvAccountSaveResult> saveCredentials(
    TvServerCredentials credentials,
  ) async {
    if (!credentials.canLogin) {
      return const TvAccountSaveResult(
        success: false,
        message: '请填写服务器地址、账号和密码',
      );
    }

    final baseUrl = _normalizeServerUrl(credentials.serverUrl);
    final currentServerUrl = await UserDataService.getServerUrl() ?? '';
    final currentUsername = await UserDataService.getUsername() ?? '';
    final currentCookies = await UserDataService.getCookies() ?? '';
    final isSameAccount =
        currentServerUrl.trim().toLowerCase() == baseUrl.toLowerCase() &&
            currentUsername.trim().toLowerCase() ==
                credentials.username.trim().toLowerCase();

    await UserDataService.saveUserData(
      serverUrl: baseUrl,
      username: credentials.username.trim(),
      password: credentials.password,
      cookies: isSameAccount ? currentCookies : '',
    );

    return const TvAccountSaveResult(
      success: true,
      message: '服务器配置已保存',
    );
  }

  /// 保存服务器账号并登录。
  ///
  /// 登录成功后写入 cookies，并切换为服务器模式。
  Future<TvAccountSaveResult> saveAndLogin(
    TvServerCredentials credentials,
  ) async {
    if (!credentials.canLogin) {
      return const TvAccountSaveResult(
        success: false,
        message: '请填写服务器地址、账号和密码',
      );
    }

    final baseUrl = _normalizeServerUrl(credentials.serverUrl);
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'username': credentials.username.trim(),
              'password': credentials.password,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return TvAccountSaveResult(
          success: false,
          message: response.statusCode == 401 ? '账号或密码错误' : '登录失败',
        );
      }

      await UserDataService.saveUserData(
        serverUrl: baseUrl,
        username: credentials.username.trim(),
        password: credentials.password,
        cookies: _parseCookies(response),
      );
      await UserDataService.saveIsLocalMode(false);

      return const TvAccountSaveResult(
        success: true,
        message: '服务器配置已保存',
      );
    } catch (_) {
      return const TvAccountSaveResult(
        success: false,
        message: '服务器连接失败',
      );
    }
  }

  /// 标准化服务器地址。
  static String _normalizeServerUrl(String rawUrl) {
    var value = rawUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// 从登录响应解析 cookies。
  static String _parseCookies(http.Response response) {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) {
      return '';
    }
    return setCookieHeaders
        .split(',')
        .map((item) => item.split(';').first.trim())
        .where((item) => item.isNotEmpty)
        .join('; ');
  }
}
