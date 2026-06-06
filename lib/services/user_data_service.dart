import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tv_player_kernel.dart';
import '../models/playback_preload.dart';
import '../models/search_result.dart';

class SavedUserAccount {
  final String serverUrl;
  final String username;
  final String password;
  final String cookies;
  final int updatedAt;

  const SavedUserAccount({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.cookies,
    required this.updatedAt,
  });

  bool get hasLoginSession => cookies.trim().isNotEmpty;

  String get accountKey =>
      '${serverUrl.trim().toLowerCase()}|${username.trim().toLowerCase()}';

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'cookies': cookies,
      'updatedAt': updatedAt,
    };
  }

  factory SavedUserAccount.fromJson(Map<String, dynamic> json) {
    return SavedUserAccount(
      serverUrl: (json['serverUrl'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      cookies: (json['cookies'] ?? '').toString(),
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  SavedUserAccount copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? cookies,
    int? updatedAt,
  }) {
    return SavedUserAccount(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      cookies: cookies ?? this.cookies,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserDataService {
  // --- 登录与身份验证相关 ---
  /// 服务器地址 Key
  static const String _serverUrlKey = 'server_url';

  /// 用户名 Key
  static const String _usernameKey = 'username';

  /// 密码 Key
  static const String _passwordKey = 'password';

  /// 登录 Cookies Key
  static const String _cookiesKey = 'cookies';
  static const String _savedAccountsKey = 'saved_user_accounts_v1';

  // --- 应用全局配置相关 ---
  /// 豆瓣数据源设置 Key
  static const String _doubanDataSourceKey = 'douban_data_source';

  /// 豆瓣图片源设置 Key
  static const String _doubanImageSourceKey = 'douban_image_source';

  /// M3U8 代理 URL Key
  static const String _m3u8ProxyUrlKey = 'm3u8_proxy_url';

  /// M3U8 代理 URL 内存缓存。
  ///
  /// TV 详情页和 TV 全屏播放器在起播、换集、换源时会频繁读取该配置。
  /// 这里保留一份进程内缓存，避免每次主链路都重复等待 `SharedPreferences`。
  static String _cachedM3u8ProxyUrl = '';

  /// M3U8 代理 URL 是否已经完成过一次内存预热。
  static bool _hasCachedM3u8ProxyUrl = false;

  /// 是否开启优选测速 Key
  static const String _preferSpeedTestKey = 'prefer_speed_test';

  /// 是否开启本地搜索 Key
  static const String _localSearchKey = 'local_search';

  /// 是否显示直播入口 Key
  static const String _showLiveKey = 'show_live_v1';

  /// 是否显示源浏览器入口 Key
  static const String _showSourceBrowserKey = 'show_source_browser_v1';

  /// 源浏览器当前选中的数据源 Key
  static const String _sourceBrowserCurrentSourceKey =
      'source_browser_current_source_v1';

  /// 是否处于离线/本地模式 Key
  static const String _isLocalModeKey = 'is_local_mode';

  // --- 播放器偏好设置相关 ---
  /// 全局跳过片头时长 Key
  static const String _skipIntroKey = 'skip_intro_duration';

  /// 全局跳过片尾时长 Key
  static const String _skipOutroKey = 'skip_outro_duration';

  /// 播放器长按倍速设置 Key
  static const String _longPressSpeedKey = 'long_press_speed';

  /// 视频画面比例设置 Key
  static const String _videoFitTypeKey = 'video_fit_type';

  /// 隐藏控制栏时的进度显示模式 Key
  static const String _progressDisplayModeKey = 'progress_display_mode';

  /// 是否显示系统时间 Key
  static const String _showSystemTimeKey = 'show_system_time';

  /// 中间播放按钮是否跟随顶部/底部按钮一起隐藏 Key
  static const String _hideCenterControlsWithBarsKey =
      'hide_center_controls_with_bars';

  /// 是否开启自动去广告 Key
  static const String _adFilterEnabledKey = 'ad_filter_enabled';

  /// TV 播放器内核 Key
  static const String _tvPlayerKernelKey = 'tv_player_kernel_v1';

  /// macOS media_kit 预加载 Key
  static const String _mediaKitPreloadEnabledKey = 'media_kit_preload_enabled';

  /// 全平台在线播放预加载 Key
  static const String _playbackPreloadEnabledKey =
      'playback_preload_enabled_v1';

  /// 全平台在线播放预加载级别 Key
  static const String _playbackPreloadLevelKey = 'playback_preload_level_v1';

  /// WebView 播放器 hls.js 脚本源码缓存 Key
  static const String _hlsJsCacheKey = 'hls_js_cache_v1';

  /// 视频特定跳过设置的 Key 前缀
  static const String _videoSkipSettingsPrefix = 'video_skip_v2_';

  /// 保存 hls.js 缓存
  static Future<void> saveHlsJsCache(String content) async {
    if (content.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hlsJsCacheKey, content);
  }

  /// 获取 hls.js 缓存
  static Future<String?> getHlsJsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hlsJsCacheKey);
  }

  /// 清除 hls.js 缓存
  static Future<void> clearHlsJsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hlsJsCacheKey);
  }

  /// 获取特定视频的跳过设置 Key
  static String _getVideoSkipKey(String title, String? year) {
    // 移除文件名/标题中可能影响存储的特殊字符，并结合年份
    final cleanTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '$_videoSkipSettingsPrefix${cleanTitle}_${year ?? 'unknown'}';
  }

  /// 保存特定视频的跳过设置
  static Future<void> saveVideoSkipSettings(
      String title, String? year, int intro, int outro) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getVideoSkipKey(title, year);
    final millisecondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(
        key,
        json.encode(
            {'intro': intro, 'outro': outro, 'time': millisecondsSinceEpoch}));
    debugPrint(
        "缓存片头片尾，片名：$key, 年份：$year, 数据：{'intro': $intro, 'outro': $outro, 'time': $millisecondsSinceEpoch}");
  }

  /// 获取特定视频的跳过设置
  static Future<Map<String, int>?> getVideoSkipSettings(
      String title, String? year) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getVideoSkipKey(title, year);
      final String? data = prefs.getString(key);
      if (data != null) {
        final Map<String, dynamic> decoded = json.decode(data);
        return {
          'intro': decoded['intro'] as int,
          'outro': decoded['outro'] as int
        };
      }
    } catch (e) {
      debugPrint('获取视频特定跳过设置失败: $e');
    }
    return null;
  }

  // --- 搜索与业务数据缓存 ---
  /// 搜索源数据持久化缓存 Key
  static const String _sourcesCacheStorageKey = 'sources_data_cache_persistent';

  /// 搜索结果内存缓存 Map (Query -> (Results, DateTime))
  static Map<String, (List<SearchResult>, DateTime)> _sourcesDataCache = {};

  /// 搜索缓存有效期 (2小时)
  static const Duration _sourcesDataCacheTtl = Duration(seconds: 7200);

  /// 重置进程内缓存，供测试隔离使用。
  @visibleForTesting
  static void debugResetMemoryCaches() {
    _cachedM3u8ProxyUrl = '';
    _hasCachedM3u8ProxyUrl = false;
    _tvPlayerKernelCache = null;
  }

  /// 搜索缓存是否已从磁盘加载标识
  static bool _isCacheLoaded = false;

  /// 加载搜索缓存
  static Future<void> _ensureSearchCacheLoaded() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_sourcesCacheStorageKey);
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        final now = DateTime.now();
        final Map<String, (List<SearchResult>, DateTime)> loadedCache = {};

        decoded.forEach((key, value) {
          final time = DateTime.fromMillisecondsSinceEpoch(value['time']);
          if (now.difference(time) < _sourcesDataCacheTtl) {
            final results = (value['results'] as List)
                .map((item) => SearchResult.fromJson(item))
                .toList();
            loadedCache[key] = (results, time);
          }
        });
        _sourcesDataCache = loadedCache;
      }
    } catch (e) {
      debugPrint('加载搜索源持久化缓存失败: $e');
    }
    _isCacheLoaded = true;
  }

  /// 同步搜索缓存至磁盘
  static Future<void> _syncSearchCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      _sourcesDataCache.removeWhere(
          (key, value) => now.difference(value.$2) >= _sourcesDataCacheTtl);

      final Map<String, dynamic> toEncode = {};
      _sourcesDataCache.forEach((key, value) {
        toEncode[key] = {
          'time': value.$2.millisecondsSinceEpoch,
          'results': value.$1.map((r) => r.toJson()).toList(),
        };
      });

      await prefs.setString(_sourcesCacheStorageKey, json.encode(toEncode));
    } catch (e) {
      debugPrint('保存搜索源持久化缓存失败: $e');
    }
  }

  /// 获取搜索结果缓存
  static Future<List<SearchResult>?> getSearchCache(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    await _ensureSearchCacheLoaded();

    if (_sourcesDataCache.containsKey(cleanQuery)) {
      final (results, timestamp) = _sourcesDataCache[cleanQuery]!;
      if (DateTime.now().difference(timestamp) < _sourcesDataCacheTtl) {
        // 自动续约
        renewSearchCache(cleanQuery);
        return results;
      } else {
        _sourcesDataCache.remove(cleanQuery);
        unawaited(_syncSearchCacheToStorage());
      }
    }
    return null;
  }

  /// 保存搜索结果缓存
  static Future<void> saveSearchCache(
      String query, List<SearchResult> results) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    await _ensureSearchCacheLoaded();
    _sourcesDataCache[cleanQuery] = (results, DateTime.now());
    await _syncSearchCacheToStorage();
  }

  /// 续约搜索缓存（延长到期时间）
  static void renewSearchCache(String query) {
    final cleanQuery = query.trim();
    if (_sourcesDataCache.containsKey(cleanQuery)) {
      _sourcesDataCache[cleanQuery] =
          (_sourcesDataCache[cleanQuery]!.$1, DateTime.now());
      _syncSearchCacheToStorage();
    }
  }

  /// 清除所有搜索缓存
  static Future<void> clearSearchCache() async {
    _sourcesDataCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sourcesCacheStorageKey);
  }

  // --- 运行时内存缓存 ---
  /// 本地模式状态的内存缓存，用于同步读取
  static bool? _isLocalModeCache;

  /// TV 播放器内核的内存缓存。
  static TvPlayerKernel? _tvPlayerKernelCache;

  // 保存去广告开关
  static Future<void> saveAdFilterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adFilterEnabledKey, enabled);
  }

  // 获取去广告开关（默认 true）
  static Future<bool> getAdFilterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adFilterEnabledKey) ?? true;
  }

  /// 保存 TV 播放器内核。
  static Future<void> saveTvPlayerKernel(TvPlayerKernel kernel) async {
    _tvPlayerKernelCache = kernel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tvPlayerKernelKey, kernel.key);
  }

  /// 获取 TV 播放器内核，未配置时默认使用 Exo。
  static Future<TvPlayerKernel> getTvPlayerKernel() async {
    final cachedKernel = _tvPlayerKernelCache;
    if (cachedKernel != null) {
      return cachedKernel;
    }
    final prefs = await SharedPreferences.getInstance();
    final resolvedKernel =
        TvPlayerKernel.fromKey(prefs.getString(_tvPlayerKernelKey));
    _tvPlayerKernelCache = resolvedKernel;
    return resolvedKernel;
  }

  // 保存 macOS media_kit 预加载开关
  static Future<void> saveMediaKitPreloadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mediaKitPreloadEnabledKey, enabled);
  }

  // 获取 macOS media_kit 预加载开关
  static Future<bool> getMediaKitPreloadEnabled({
    bool defaultValue = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mediaKitPreloadEnabledKey) ?? defaultValue;
  }

  // 保存全平台在线播放预加载开关
  static Future<void> savePlaybackPreloadEnabled(bool enabled) async {
    await savePlaybackPreloadLevel(
      playbackPreloadLevelFromLegacyEnabled(enabled),
    );
  }

  // 获取全平台在线播放预加载开关
  static Future<bool> getPlaybackPreloadEnabled() async {
    return (await getPlaybackPreloadLevel()).isEnabled;
  }

  // 保存全平台在线播放预加载级别
  static Future<void> savePlaybackPreloadLevel(
      PlaybackPreloadLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playbackPreloadLevelKey, level.storageValue);
  }

  // 获取全平台在线播放预加载级别
  static Future<PlaybackPreloadLevel> getPlaybackPreloadLevel() async {
    final prefs = await SharedPreferences.getInstance();

    final storedLevel = prefs.getString(_playbackPreloadLevelKey);
    if (storedLevel != null && storedLevel.isNotEmpty) {
      return playbackPreloadLevelFromStorage(storedLevel);
    }

    final legacyUnified = prefs.getBool(_playbackPreloadEnabledKey);
    if (legacyUnified != null) {
      return playbackPreloadLevelFromLegacyEnabled(legacyUnified);
    }

    final legacyMediaKit = prefs.getBool(_mediaKitPreloadEnabledKey);
    if (legacyMediaKit != null) {
      return playbackPreloadLevelFromLegacyEnabled(legacyMediaKit);
    }

    return kDefaultPlaybackPreloadLevel;
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

  // 保存中间播放按钮跟随隐藏开关
  static Future<void> saveHideCenterControlsWithBars(bool hide) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideCenterControlsWithBarsKey, hide);
  }

  // 获取中间播放按钮跟随隐藏开关（默认 true）
  static Future<bool> getHideCenterControlsWithBars() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideCenterControlsWithBarsKey) ?? true;
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
  static String _buildAccountKey(String serverUrl, String username) {
    return '${serverUrl.trim().toLowerCase()}|${username.trim().toLowerCase()}';
  }

  static List<SavedUserAccount> _parseSavedAccounts(String? jsonText) {
    if (jsonText == null || jsonText.trim().isEmpty) {
      return [];
    }
    try {
      final decoded = json.decode(jsonText);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
              (item) => SavedUserAccount.fromJson(item.cast<String, dynamic>()))
          .where((item) =>
              item.serverUrl.trim().isNotEmpty &&
              item.username.trim().isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('解析已保存账号失败: $e');
      return [];
    }
  }

  static Future<List<SavedUserAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString(_savedAccountsKey);
    final accounts = _parseSavedAccounts(savedText);
    accounts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return accounts;
  }

  static Future<void> _saveSavedAccounts(
    SharedPreferences prefs,
    List<SavedUserAccount> accounts,
  ) async {
    final sorted = [...accounts];
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _savedAccountsKey,
      json.encode(sorted.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> _upsertSavedAccount({
    required SharedPreferences prefs,
    required String serverUrl,
    required String username,
    required String password,
    required String cookies,
  }) async {
    final existing = _parseSavedAccounts(prefs.getString(_savedAccountsKey));
    final targetKey = _buildAccountKey(serverUrl, username);
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = <SavedUserAccount>[];
    var replaced = false;

    for (final item in existing) {
      if (item.accountKey == targetKey) {
        replaced = true;
        updated.add(item.copyWith(
          serverUrl: serverUrl,
          username: username,
          password: password,
          cookies: cookies,
          updatedAt: now,
        ));
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.add(SavedUserAccount(
        serverUrl: serverUrl,
        username: username,
        password: password,
        cookies: cookies,
        updatedAt: now,
      ));
    }

    await _saveSavedAccounts(prefs, updated);
  }

  static Future<void> switchSavedAccount(SavedUserAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await saveUserData(
      serverUrl: account.serverUrl,
      username: account.username,
      password: account.password,
      cookies: account.cookies,
    );
    await saveIsLocalMode(false);
    await _upsertSavedAccount(
      prefs: prefs,
      serverUrl: account.serverUrl,
      username: account.username,
      password: account.password,
      cookies: account.cookies,
    );
  }

  static Future<void> logoutSavedAccount(SavedUserAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await _upsertSavedAccount(
      prefs: prefs,
      serverUrl: account.serverUrl,
      username: account.username,
      password: '',
      cookies: '',
    );

    final currentServerUrl = prefs.getString(_serverUrlKey) ?? '';
    final currentUsername = prefs.getString(_usernameKey) ?? '';
    if (_buildAccountKey(currentServerUrl, currentUsername) ==
        account.accountKey) {
      await prefs.remove(_passwordKey);
      await prefs.remove(_cookiesKey);
    }
  }

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
    await _upsertSavedAccount(
      prefs: prefs,
      serverUrl: serverUrl,
      username: username,
      password: password,
      cookies: cookies,
    );
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
    final currentServerUrl = prefs.getString(_serverUrlKey) ?? '';
    final currentUsername = prefs.getString(_usernameKey) ?? '';
    await clearPasswordAndCookies();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_usernameKey);
    if (currentServerUrl.isNotEmpty && currentUsername.isNotEmpty) {
      await _upsertSavedAccount(
        prefs: prefs,
        serverUrl: currentServerUrl,
        username: currentUsername,
        password: '',
        cookies: '',
      );
    }
  }

  // 只清除密码和cookies，保留服务器地址和用户名
  static Future<void> clearPasswordAndCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final currentServerUrl = prefs.getString(_serverUrlKey) ?? '';
    final currentUsername = prefs.getString(_usernameKey) ?? '';
    await prefs.remove(_passwordKey);
    await prefs.remove(_cookiesKey);
    if (currentServerUrl.isNotEmpty && currentUsername.isNotEmpty) {
      await _upsertSavedAccount(
        prefs: prefs,
        serverUrl: currentServerUrl,
        username: currentUsername,
        password: '',
        cookies: '',
      );
    }
  }

  /// 只清除当前登录会话 cookies，保留服务器地址、用户名和密码。
  ///
  /// TV 设置页保存的是可复用的服务器配置，登录态过期时不能把这份配置一并抹掉。
  /// 这里仅移除当前会话，并同步把已保存账号里的 cookies 清空，方便后续自动续登录。
  static Future<void> clearSessionCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final currentServerUrl = prefs.getString(_serverUrlKey) ?? '';
    final currentUsername = prefs.getString(_usernameKey) ?? '';
    final currentPassword = prefs.getString(_passwordKey) ?? '';
    await prefs.remove(_cookiesKey);
    if (currentServerUrl.isNotEmpty && currentUsername.isNotEmpty) {
      await _upsertSavedAccount(
        prefs: prefs,
        serverUrl: currentServerUrl,
        username: currentUsername,
        password: currentPassword,
        cookies: '',
      );
    }
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
  static Future<void> saveDoubanImageSource(
      String imageSourceDisplayName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDoubanImageSourceKeyFromDisplayName(imageSourceDisplayName);
    await prefs.setString(_doubanImageSourceKey, key);
  }

  // 获取豆瓣图片源设置（返回key值）
  static Future<String> getDoubanImageSourceKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_doubanImageSourceKey) ?? 'official_cdn';
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
        return '豆瓣官方精品 CDN';
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
    _cachedM3u8ProxyUrl = url;
    _hasCachedM3u8ProxyUrl = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_m3u8ProxyUrlKey, url);
  }

  // 获取 M3U8 代理 URL
  static Future<String> getM3u8ProxyUrl() async {
    if (_hasCachedM3u8ProxyUrl) {
      return _cachedM3u8ProxyUrl;
    }
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_m3u8ProxyUrlKey) ?? '';
    _cachedM3u8ProxyUrl = url;
    _hasCachedM3u8ProxyUrl = true;
    return url;
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

  // 保存直播显示设置
  static Future<void> saveShowLive(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLiveKey, enabled);
  }

  // 获取直播显示设置（默认为 false）
  static Future<bool> getShowLive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showLiveKey) ?? false;
  }

  // 保存源浏览器显示设置
  static Future<void> saveShowSourceBrowser(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSourceBrowserKey, enabled);
  }

  // 获取源浏览器显示设置（默认为 false）
  static Future<bool> getShowSourceBrowser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showSourceBrowserKey) ?? false;
  }

  // 保存源浏览器当前数据源
  static Future<void> saveSourceBrowserCurrentSource(String sourceKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceBrowserCurrentSourceKey,
        sourceKey.trim().isEmpty ? 'auto' : sourceKey);
  }

  // 获取源浏览器当前数据源
  static Future<String> getSourceBrowserCurrentSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sourceBrowserCurrentSourceKey) ?? 'auto';
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
