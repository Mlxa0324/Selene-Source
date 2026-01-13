import 'package:shared_preferences/shared_preferences.dart';

class UserDataService {
  static const String _serverUrlKey = 'server_url';
  static const String _usernameKey = 'username';
  static const String _passwordKey = 'password';
  static const String _cookiesKey = 'cookies';
  static const String _doubanDataSourceKey = 'douban_data_source';
  static const String _doubanImageSourceKey = 'douban_image_source';
  static const String _m3u8ProxyUrlKey = 'm3u8_proxy_url';
  static const String _preferSpeedTestKey = 'prefer_speed_test';
  static const String _localSearchKey = 'local_search';
  static const String _isLocalModeKey = 'is_local_mode';
  static const String _skipIntroKey = 'skip_intro_duration';
  static const String _skipOutroKey = 'skip_outro_duration';
  static const String _longPressSpeedKey = 'long_press_speed';
  static const String _videoFitTypeKey = 'video_fit_type';
  static const String _progressDisplayModeKey = 'progress_display_mode';
  static const String _showSystemTimeKey = 'show_system_time';
  static const String _adFilterEnabledKey = 'ad_filter_enabled';
  
  // 内存缓存
  static bool? _isLocalModeCache;

  // 保存去广告开关
  static Future<void> saveAdFilterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adFilterEnabledKey, enabled);
  }

  // 获取去广告开关（默认 false）
  static Future<bool> getAdFilterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adFilterEnabledKey) ?? false;
  }

  // 保存长按倍速
  static Future<void> saveLongPressSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_longPressSpeedKey, speed);
  }

  // 获取长按倍速（默认 2.0）
  static Future<double> getLongPressSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_longPressSpeedKey) ?? 2.0;
  }

  // 保存画面比例
  static Future<void> saveVideoFitType(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_videoFitTypeKey, index);
  }

  // 获取画面比例（默认 0 - contain）
  static Future<int> getVideoFitType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_videoFitTypeKey) ?? 0;
  }

  // 保存进度显示模式
  static Future<void> saveProgressDisplayMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressDisplayModeKey, index);
  }

  // 获取进度显示模式（默认 0 - none）
  static Future<int> getProgressDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_progressDisplayModeKey) ?? 0;
  }

  // 保存系统时间开关
  static Future<void> saveShowSystemTime(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSystemTimeKey, show);
  }

  // 获取系统时间开关（默认 false）
  static Future<bool> getShowSystemTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showSystemTimeKey) ?? false;
  }

  // 保存跳过片头时长
  static Future<void> saveSkipIntroDuration(int duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipIntroKey, duration);
  }

  // 获取跳过片头时长（默认 0）
  static Future<int> getSkipIntroDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_skipIntroKey) ?? 0;
  }

  // 保存跳过片尾时长
  static Future<void> saveSkipOutroDuration(int duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipOutroKey, duration);
  }

  // 获取跳过片尾时长（默认 0）
  static Future<int> getSkipOutroDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_skipOutroKey) ?? 0;
  }

  // 保存用户登录信息
  static Future<void> saveUserData({
    required String serverUrl,
    required String username,
    required String password,
    required String cookies,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverUrl);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
    await prefs.setString(_cookiesKey, cookies);
  }

  // 获取服务器地址
  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  // 获取用户名
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // 获取密码
  static Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey);
  }

  // 获取cookies
  static Future<String?> getCookies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cookiesKey);
  }

  // 检查是否已登录
  static Future<bool> isLoggedIn() async {
    final cookies = await getCookies();
    return cookies != null && cookies.isNotEmpty;
  }

  // 清除用户数据
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_cookiesKey);
  }

  // 只清除密码和cookies，保留服务器地址和用户名
  static Future<void> clearPasswordAndCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passwordKey);
    await prefs.remove(_cookiesKey);
  }

  // 获取所有用户数据
  static Future<Map<String, String?>> getAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'serverUrl': prefs.getString(_serverUrlKey),
      'username': prefs.getString(_usernameKey),
      'password': prefs.getString(_passwordKey),
      'cookies': prefs.getString(_cookiesKey),
    };
  }

  // 检查是否具有自动登录所需的所有字段
  static Future<bool> hasAutoLoginData() async {
    final serverUrl = await getServerUrl();
    final username = await getUsername();
    final password = await getPassword();
    
    return serverUrl != null && 
           serverUrl.isNotEmpty && 
           username != null && 
           username.isNotEmpty && 
           password != null && 
           password.isNotEmpty;
  }

  // 保存豆瓣数据源设置（存储key值）
  static Future<void> saveDoubanDataSource(String dataSourceDisplayName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDoubanDataSourceKeyFromDisplayName(dataSourceDisplayName);
    await prefs.setString(_doubanDataSourceKey, key);
  }

  // 获取豆瓣数据源设置（返回key值）
  static Future<String> getDoubanDataSourceKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_doubanDataSourceKey) ?? 'direct';
  }

  // 获取豆瓣数据源显示名称
  static Future<String> getDoubanDataSourceDisplayName() async {
    final key = await getDoubanDataSourceKey();
    return _getDoubanDataSourceDisplayNameFromKey(key);
  }

  // 保存豆瓣图片源设置（存储key值）
  static Future<void> saveDoubanImageSource(String imageSourceDisplayName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDoubanImageSourceKeyFromDisplayName(imageSourceDisplayName);
    await prefs.setString(_doubanImageSourceKey, key);
  }

  // 获取豆瓣图片源设置（返回key值）
  static Future<String> getDoubanImageSourceKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_doubanImageSourceKey) ?? 'direct';
  }

  // 获取豆瓣图片源显示名称
  static Future<String> getDoubanImageSourceDisplayName() async {
    final key = await getDoubanImageSourceKey();
    return _getDoubanImageSourceDisplayNameFromKey(key);
  }

  // 根据显示名称获取豆瓣数据源的key值（私有方法）
  static String _getDoubanDataSourceKeyFromDisplayName(String dataSource) {
    switch (dataSource) {
      case '直连':
        return 'direct';
      case 'Cors Proxy By Zwei':
        return 'cors_proxy';
      case '豆瓣 CDN By CMLiussss（腾讯云）':
        return 'cdn_tencent';
      case '豆瓣 CDN By CMLiussss（阿里云）':
        return 'cdn_aliyun';
      default:
        return 'direct';
    }
  }

  // 根据显示名称获取豆瓣图片源的key值（私有方法）
  static String _getDoubanImageSourceKeyFromDisplayName(String imageSource) {
    switch (imageSource) {
      case '直连':
        return 'direct';
      case '豆瓣官方精品 CDN':
        return 'official_cdn';
      case '豆瓣 CDN By CMLiussss（腾讯云）':
        return 'cdn_tencent';
      case '豆瓣 CDN By CMLiussss（阿里云）':
        return 'cdn_aliyun';
      default:
        return 'direct';
    }
  }

  // 根据key值获取豆瓣数据源显示名称（私有方法）
  static String _getDoubanDataSourceDisplayNameFromKey(String key) {
    switch (key) {
      case 'direct':
        return '直连';
      case 'cors_proxy':
        return 'Cors Proxy By Zwei';
      case 'cdn_tencent':
        return '豆瓣 CDN By CMLiussss（腾讯云）';
      case 'cdn_aliyun':
        return '豆瓣 CDN By CMLiussss（阿里云）';
      default:
        return '直连';
    }
  }

  // 根据key值获取豆瓣图片源显示名称（私有方法）
  static String _getDoubanImageSourceDisplayNameFromKey(String key) {
    switch (key) {
      case 'direct':
        return '直连';
      case 'official_cdn':
        return '豆瓣官方精品 CDN';
      case 'cdn_tencent':
        return '豆瓣 CDN By CMLiussss（腾讯云）';
      case 'cdn_aliyun':
        return '豆瓣 CDN By CMLiussss（阿里云）';
      default:
        return '直连';
    }
  }

  // 保存 M3U8 代理 URL
  static Future<void> saveM3u8ProxyUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_m3u8ProxyUrlKey, url);
  }

  // 获取 M3U8 代理 URL
  static Future<String> getM3u8ProxyUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3u8ProxyUrlKey) ?? '';
  }

  // 保存优选测速设置
  static Future<void> savePreferSpeedTest(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferSpeedTestKey, enabled);
  }

  // 获取优选测速设置（默认为 true）
  static Future<bool> getPreferSpeedTest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_preferSpeedTestKey) ?? true;
  }

  // 保存本地搜索设置
  static Future<void> saveLocalSearch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localSearchKey, enabled);
  }

  // 获取本地搜索设置（默认为 false）
  static Future<bool> getLocalSearch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localSearchKey) ?? false;
  }

  // 保存本地模式设置
  static Future<void> saveIsLocalMode(bool isLocalMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLocalModeKey, isLocalMode);
    _isLocalModeCache = isLocalMode; // 同步更新内存缓存
  }

  // 获取本地模式设置（默认为 false）
  static Future<bool> getIsLocalMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_isLocalModeKey) ?? false;
    _isLocalModeCache = value; // 缓存到内存
    return value;
  }
  
  // 同步获取本地模式设置（从内存缓存读取）
  static bool getIsLocalModeSync() {
    return _isLocalModeCache ?? false;
  }
}
