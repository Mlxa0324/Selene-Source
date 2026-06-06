import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:selene/config/tv_player_kernel.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/services/app_cache_service.dart';
import 'package:selene/services/danmaku_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_account_config_service.dart';
import 'package:selene/tv_app/services/tv_mobile_settings_bridge.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';

/// 设置页焦点滚动对齐位置。
///
/// 纵向浏览设置项时，让获焦控件尽量稳定停留在视口下半区，
/// 给顶部二维码与说明区留出更完整的展示空间。
const double _tvSettingsFocusScrollAlignment = 0.72;

/// TV 设置数据加载函数。
typedef TvSettingsLoader = Future<TvSettingsData> Function();

/// TV 服务器账号保存函数。
typedef TvAccountSaver = Future<TvAccountSaveResult> Function(
  TvServerCredentials credentials,
);

/// TV 弹幕设置保存函数。
typedef TvDanmakuSaver = Future<void> Function(
  String baseApi,
  DanmakuSettings settings,
);

/// TV 图片代理保存函数。
typedef TvImageSourceSaver = Future<void> Function(String imageSource);

/// TV 自动去广告开关读取函数。
typedef TvAdFilterLoader = Future<bool> Function();

/// TV 自动去广告开关保存函数。
typedef TvAdFilterSaver = Future<void> Function(bool enabled);

/// TV 播放器内核保存函数。
typedef TvPlayerKernelSaver = Future<void> Function(String playerKernelKey);

/// TV 主题色保存函数。
typedef TvThemeSaver = Future<void> Function(String themeKey);

/// TV 背景色保存函数。
typedef TvBackgroundSaver = Future<void> Function(String backgroundKey);

/// TV 焦点效果保存函数。
typedef TvFocusEffectSaver = Future<void> Function(String focusEffectModeKey);

/// TV 缓存大小加载函数。
typedef TvCacheSizeLoader = Future<int> Function();

/// TV 缓存清理函数。
typedef TvCacheCleaner = Future<void> Function();

/// TV 手机扫码配置桥接启动函数。
typedef TvMobileConfigBridgeStarter = Future<TvMobileSettingsBridgeSession>
    Function(
  TvMobileSettingsDraft initialDraft,
  ValueChanged<TvMobileSettingsDraft> onDraftSubmitted,
);

/// TV 设置页主操作提示类型。
enum _TvSettingsActionNoticeType {
  /// 保存或清理成功提示。
  success,

  /// 保存或清理失败提示。
  error,
}

/// TV 设置页聚合数据。
class TvSettingsData {
  /// 创建 TV 设置页聚合数据。
  const TvSettingsData({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.themeKey = TvThemePalette.netflixRedKey,
    this.backgroundKey = TvThemeBackground.deepBlueKey,
    this.focusEffectModeKey = TvFocusEffectMode.magnifierKey,
    this.playerKernelKey = 'exo',
    required this.adFilterEnabled,
    required this.doubanImageSource,
    required this.danmakuBaseApi,
    required this.danmakuSettings,
  });

  /// 服务器地址。
  final String serverUrl;

  /// 账号。
  final String username;

  /// 密码。
  final String password;

  /// TV 主题色标识。
  final String themeKey;

  /// TV 页面背景色标识。
  final String backgroundKey;

  /// TV 焦点效果标识。
  final String focusEffectModeKey;

  /// TV 播放器内核标识。
  final String playerKernelKey;

  /// 是否开启自动去广告。
  final bool adFilterEnabled;

  /// 豆瓣图片代理显示名称。
  final String doubanImageSource;

  /// 弹幕服务器地址。
  final String danmakuBaseApi;

  /// 弹幕显示设置。
  final DanmakuSettings danmakuSettings;

  /// 空配置。
  factory TvSettingsData.empty() {
    return const TvSettingsData(
      serverUrl: '',
      username: '',
      password: '',
      themeKey: TvThemePalette.netflixRedKey,
      backgroundKey: TvThemeBackground.deepBlueKey,
      focusEffectModeKey: TvFocusEffectMode.magnifierKey,
      playerKernelKey: 'exo',
      adFilterEnabled: true,
      doubanImageSource: '豆瓣官方精品 CDN',
      danmakuBaseApi: '',
      danmakuSettings: DanmakuSettings(),
    );
  }
}

/// TV 设置页。
///
/// 提供服务器账号与弹幕配置，底层复用普通端已有存储。
class TvSettingsScreen extends StatefulWidget {
  /// 创建 TV 设置页。
  const TvSettingsScreen({
    super.key,
    this.loadSettings,
    this.saveAccount,
    this.saveTheme,
    this.saveBackground,
    this.saveFocusEffect,
    this.saveDoubanImageSource,
    this.savePlayerKernel,
    this.loadAdFilterEnabled,
    this.saveAdFilterEnabled,
    this.saveDanmaku,
    this.loadCacheSize,
    this.clearAllCaches,
    this.startMobileConfigBridge,
  });

  /// 设置加载函数。
  final TvSettingsLoader? loadSettings;

  /// 账号保存函数。
  final TvAccountSaver? saveAccount;

  /// 主题色保存函数。
  final TvThemeSaver? saveTheme;

  /// 背景色保存函数。
  final TvBackgroundSaver? saveBackground;

  /// 焦点效果保存函数。
  final TvFocusEffectSaver? saveFocusEffect;

  /// 图片代理保存函数。
  final TvImageSourceSaver? saveDoubanImageSource;

  /// 播放器内核保存函数。
  final TvPlayerKernelSaver? savePlayerKernel;

  /// 自动去广告开关读取函数。
  final TvAdFilterLoader? loadAdFilterEnabled;

  /// 自动去广告开关保存函数。
  final TvAdFilterSaver? saveAdFilterEnabled;

  /// 弹幕设置保存函数。
  final TvDanmakuSaver? saveDanmaku;

  /// 缓存大小加载函数。
  final TvCacheSizeLoader? loadCacheSize;

  /// 清理全部缓存函数。
  final TvCacheCleaner? clearAllCaches;

  /// 手机扫码配置桥接启动函数。
  final TvMobileConfigBridgeStarter? startMobileConfigBridge;

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();

  /// 默认设置加载逻辑。
  static Future<TvSettingsData> defaultLoadSettings() async {
    final accountService = TvAccountConfigService();
    final credentials = await accountService.loadCredentials();
    final danmakuService = DanmakuService();
    return TvSettingsData(
      serverUrl: credentials.serverUrl,
      username: credentials.username,
      password: credentials.password,
      themeKey: await TvThemeService.loadSavedThemeKey(),
      backgroundKey: await TvThemeService.loadSavedBackgroundKey(),
      focusEffectModeKey: await TvThemeService.loadSavedFocusEffectModeKey(),
      playerKernelKey: (await UserDataService.getTvPlayerKernel()).key,
      adFilterEnabled: await UserDataService.getAdFilterEnabled(),
      doubanImageSource:
          await UserDataService.getDoubanImageSourceDisplayName(),
      danmakuBaseApi: await danmakuService.getBaseApi() ?? '',
      danmakuSettings: await danmakuService.getSettings(),
    );
  }

  /// 默认账号保存逻辑。
  static Future<TvAccountSaveResult> defaultSaveAccount(
    TvServerCredentials credentials,
  ) {
    return TvAccountConfigService().saveCredentials(credentials);
  }

  /// 默认弹幕保存逻辑。
  static Future<void> defaultSaveDanmaku(
    String baseApi,
    DanmakuSettings settings,
  ) async {
    final service = DanmakuService();
    await service.setBaseApi(baseApi.trim());
    await service.saveSettings(settings);
  }

  /// 默认图片代理保存逻辑。
  static Future<void> defaultSaveDoubanImageSource(String imageSource) {
    return UserDataService.saveDoubanImageSource(imageSource);
  }

  /// 默认播放器内核保存逻辑。
  static Future<void> defaultSavePlayerKernel(String playerKernelKey) {
    return UserDataService.saveTvPlayerKernel(
      TvPlayerKernel.fromKey(playerKernelKey),
    );
  }

  /// 默认自动去广告保存逻辑。
  static Future<void> defaultSaveAdFilterEnabled(bool enabled) {
    return UserDataService.saveAdFilterEnabled(enabled);
  }

  /// 默认主题色保存逻辑。
  static Future<void> defaultSaveTheme(String themeKey) {
    return TvThemeService.saveThemeKey(themeKey);
  }

  /// 默认背景色保存逻辑。
  static Future<void> defaultSaveBackground(String backgroundKey) {
    return TvThemeService.saveBackgroundKey(backgroundKey);
  }

  /// 默认焦点效果保存逻辑。
  static Future<void> defaultSaveFocusEffect(String focusEffectModeKey) {
    return TvThemeService.saveFocusEffectModeKey(focusEffectModeKey);
  }

  /// 默认缓存大小加载逻辑。
  static Future<int> defaultLoadCacheSize() {
    return AppCacheService().calculateCacheSizeBytes();
  }

  /// 默认清理全部缓存逻辑。
  static Future<void> defaultClearAllCaches() {
    return AppCacheService().clearAllCaches();
  }
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  /// 页面内容最大宽度。
  static const double _contentMaxWidth = 1360;

  /// 固定页头距离顶部的安全留白。
  static const double _headerTopPadding = 20;

  /// 固定页头与滚动内容之间的垂直间距。
  static const double _headerBottomSpacing = 15;

  /// 分组面板之间的垂直间距。
  static const double _panelSpacing = 24;

  /// 服务器地址输入控制器。
  final TextEditingController _serverUrlController = TextEditingController();

  /// 账号输入控制器。
  final TextEditingController _usernameController = TextEditingController();

  /// 密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 弹幕服务器输入控制器。
  final TextEditingController _danmakuBaseApiController =
      TextEditingController();

  /// 首个服务器地址输入框的浏览态焦点。
  ///
  /// 设置页进入后会先把首焦点下发到这里，避免停留在页面根焦点上。
  final FocusNode _serverUrlBrowseFocusNode = FocusNode(
    debugLabel: 'tv-settings-server-url-browse',
  );

  /// 账号输入框的浏览态焦点。
  final FocusNode _usernameBrowseFocusNode = FocusNode(
    debugLabel: 'tv-settings-username-browse',
  );

  /// 密码输入框的浏览态焦点。
  final FocusNode _passwordBrowseFocusNode = FocusNode(
    debugLabel: 'tv-settings-password-browse',
  );

  /// 保存服务器配置按钮焦点。
  final FocusNode _saveAccountFocusNode = FocusNode(
    debugLabel: 'tv-settings-save-account-button',
  );

  /// 弹幕服务器地址输入框的浏览态焦点。
  final FocusNode _danmakuBaseApiBrowseFocusNode = FocusNode(
    debugLabel: 'tv-settings-danmaku-base-api-browse',
  );

  /// 自动去广告开关行焦点。
  final FocusNode _adFilterFocusNode = FocusNode(
    debugLabel: 'tv-settings-ad-filter-row',
  );

  /// 弹幕开关行焦点。
  final FocusNode _danmakuEnabledFocusNode = FocusNode(
    debugLabel: 'tv-settings-danmaku-enabled-row',
  );

  /// 弹幕不透明度焦点。
  final FocusNode _danmakuOpacityFocusNode = FocusNode(
    debugLabel: 'tv-settings-opacity-row',
  );

  /// 弹幕字体缩放焦点。
  final FocusNode _danmakuScaleFocusNode = FocusNode(
    debugLabel: 'tv-settings-scale-row',
  );

  /// 弹幕显示区域焦点。
  final FocusNode _danmakuDisplayAreaFocusNode = FocusNode(
    debugLabel: 'tv-settings-display-area-row',
  );

  /// 弹幕防止重叠焦点。
  final FocusNode _danmakuPreventOverlapFocusNode = FocusNode(
    debugLabel: 'tv-settings-prevent-overlap-row',
  );

  /// 弹幕同步视频速度焦点。
  final FocusNode _danmakuSyncVideoSpeedFocusNode = FocusNode(
    debugLabel: 'tv-settings-sync-video-speed-row',
  );

  /// 保存弹幕配置按钮焦点。
  final FocusNode _saveDanmakuFocusNode = FocusNode(
    debugLabel: 'tv-settings-save-danmaku-button',
  );

  /// 清除缓存按钮焦点。
  final FocusNode _clearCachesFocusNode = FocusNode(
    debugLabel: 'tv-settings-clear-caches-button',
  );

  /// 设置加载任务。
  late Future<TvSettingsData> _settingsFuture;

  /// 缓存大小加载任务。
  late Future<int> _cacheSizeFuture;

  /// 当前弹幕设置。
  DanmakuSettings _danmakuSettings = const DanmakuSettings();

  /// 当前豆瓣图片代理。
  String _doubanImageSource = '豆瓣官方精品 CDN';

  /// 当前 TV 播放器内核标识。
  String _playerKernelKey = TvPlayerKernel.exo.key;

  /// 当前是否开启自动去广告。
  bool _adFilterEnabled = true;

  /// 当前 TV 主题色标识。
  String _themeKey = TvThemePalette.defaultPalette.key;

  /// 当前 TV 页面背景色标识。
  String _backgroundKey = TvThemeBackground.deepBlue.key;

  /// 当前 TV 焦点效果标识。
  String _focusEffectModeKey = TvFocusEffectMode.defaultMode.key;

  /// 是否已把加载数据同步到输入框。
  bool _appliedLoadedData = false;

  /// 是否已派发过首个设置项焦点。
  bool _didDispatchInitialFieldFocus = false;

  /// 是否正在保存账号。
  bool _savingAccount = false;

  /// 是否正在保存弹幕设置。
  bool _savingDanmaku = false;

  /// 是否正在清理缓存。
  bool _clearingCaches = false;

  /// 是否正在处理手机扫码推送的自动保存。
  bool _savingMobileSubmittedDraft = false;

  /// 当前手机扫码配置桥接会话。
  TvMobileSettingsBridgeSession? _mobileConfigBridgeSession;

  /// 重新生成二维码按钮焦点。
  final FocusNode _regenerateQrFocusNode = FocusNode(
    debugLabel: 'tv-settings-regenerate-qr-button',
  );

  /// 当前主操作提示文案。
  ///
  /// 三颗主操作按钮统一使用页内浮层提示，避免独立设置页路由
  /// 把提示画到上一层 Scaffold 里，导致离开页面后才看得到。
  String? _actionNoticeMessage;

  /// 当前主操作提示类型。
  _TvSettingsActionNoticeType? _actionNoticeType;

  /// 主操作提示自动关闭定时器。
  Timer? _actionNoticeTimer;

  /// 标记当前是否运行在 `flutter test` 环境。
  ///
  /// 设置页默认会启动手机扫码桥接服务；widget test 下不应真的起
  /// `HttpServer` 和局域网地址探测，否则容易把测试执行器挂住。
  static bool get _isFlutterTestEnvironment {
    final flutterTest = Platform.environment['FLUTTER_TEST'];
    return flutterTest != null && flutterTest != 'false';
  }

  @override
  void initState() {
    super.initState();
    _settingsFuture =
        (widget.loadSettings ?? TvSettingsScreen.defaultLoadSettings)();
    _cacheSizeFuture =
        (widget.loadCacheSize ?? TvSettingsScreen.defaultLoadCacheSize)();
    _serverUrlController.addListener(_syncMobileConfigDraft);
    _usernameController.addListener(_syncMobileConfigDraft);
    _passwordController.addListener(_syncMobileConfigDraft);
    _danmakuBaseApiController.addListener(_syncMobileConfigDraft);
    _startMobileConfigBridge();
  }

  @override
  void dispose() {
    _actionNoticeTimer?.cancel();
    unawaited(_mobileConfigBridgeSession?.dispose() ?? Future<void>.value());
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _danmakuBaseApiController.dispose();
    _serverUrlBrowseFocusNode.dispose();
    _usernameBrowseFocusNode.dispose();
    _passwordBrowseFocusNode.dispose();
    _regenerateQrFocusNode.dispose();
    _saveAccountFocusNode.dispose();
    _danmakuBaseApiBrowseFocusNode.dispose();
    _adFilterFocusNode.dispose();
    _danmakuEnabledFocusNode.dispose();
    _danmakuOpacityFocusNode.dispose();
    _danmakuScaleFocusNode.dispose();
    _danmakuDisplayAreaFocusNode.dispose();
    _danmakuPreventOverlapFocusNode.dispose();
    _danmakuSyncVideoSpeedFocusNode.dispose();
    _saveDanmakuFocusNode.dispose();
    _clearCachesFocusNode.dispose();
    super.dispose();
  }

  /// 启动手机扫码配置桥接。
  ///
  /// TV 端页面会在进入设置页后立即生成一个局域网页面，
  /// 让手机扫码后直接填写服务器、图片代理和弹幕地址。
  Future<void> _startMobileConfigBridge() async {
    final session = await _createMobileConfigBridgeSession(
      allocateNewPort: false,
    );
    if (!mounted) {
      await session.dispose();
      return;
    }
    setState(() {
      _mobileConfigBridgeSession = session;
    });
  }

  /// 重新生成手机扫码配置会话。
  Future<void> _restartMobileConfigBridge() async {
    final previousSession = _mobileConfigBridgeSession;
    setState(() {
      _mobileConfigBridgeSession = null;
    });
    await previousSession?.dispose();
    if (!mounted) {
      return;
    }
    final session = await _createMobileConfigBridgeSession(
      allocateNewPort: true,
    );
    if (!mounted) {
      await session.dispose();
      return;
    }
    setState(() {
      _mobileConfigBridgeSession = session;
    });
  }

  /// 创建手机扫码配置桥接会话。
  ///
  /// 默认实现支持“手动重生成时分配新端口”；测试注入的假桥接仍沿用旧签名。
  Future<TvMobileSettingsBridgeSession> _createMobileConfigBridgeSession({
    required bool allocateNewPort,
  }) {
    final starter = widget.startMobileConfigBridge;
    if (starter != null) {
      return starter(
        _buildMobileSettingsDraft(),
        _applyMobileSettingsDraft,
      );
    }
    if (_isFlutterTestEnvironment) {
      return Future<TvMobileSettingsBridgeSession>.value(
        _createTestBridgeSession(),
      );
    }
    return TvMobileSettingsBridge.startSession(
      _buildMobileSettingsDraft(),
      _applyMobileSettingsDraft,
      allocateNewPort: allocateNewPort,
    );
  }

  /// 构建测试环境下的无副作用扫码桥接会话。
  ///
  /// 真实扫码桥接会绑定局域网端口；widget test 只需要稳定渲染设置页，
  /// 因此这里返回空地址会话，避免测试期间留下悬挂的服务端资源。
  TvMobileSettingsBridgeSession _createTestBridgeSession() {
    final statusNotifier = ValueNotifier<String>(
      TvMobileSettingsBridge.unavailableStatus,
    );
    return TvMobileSettingsBridgeSession(
      shareUri: null,
      statusNotifier: statusNotifier,
      updateDraft: (_) {},
      dispose: () async {
        statusNotifier.dispose();
      },
    );
  }

  /// 根据当前页面状态构建手机端草稿。
  TvMobileSettingsDraft _buildMobileSettingsDraft() {
    return TvMobileSettingsDraft(
      serverUrl: _serverUrlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      doubanImageSource: _doubanImageSource,
      adFilterEnabled: _adFilterEnabled,
      danmakuBaseApi: _danmakuBaseApiController.text,
    );
  }

  /// 把当前页面草稿同步到手机配置网页。
  void _syncMobileConfigDraft() {
    _mobileConfigBridgeSession?.updateDraft(_buildMobileSettingsDraft());
  }

  /// 应用手机端提交回来的配置草稿。
  void _applyMobileSettingsDraft(TvMobileSettingsDraft draft) {
    if (!mounted) {
      return;
    }

    setState(() {
      // 先更新输入型字段，避免手机提交后还要在电视上重新逐字录入。
      _serverUrlController.text = draft.serverUrl;
      _usernameController.text = draft.username;
      _passwordController.text = draft.password;
      _doubanImageSource = draft.doubanImageSource;
      _adFilterEnabled = draft.adFilterEnabled;
      _danmakuBaseApiController.text = draft.danmakuBaseApi;
    });
    _syncMobileConfigDraft();
    // 手机端确认提交后，TV 端直接沿用当前设置页已有保存链路落库，
    // 避免用户还要再用遥控器逐项确认一遍。
    unawaited(_autoSaveMobileSettingsDraft(draft));
  }

  /// 自动保存手机扫码推送回来的配置。
  Future<void> _autoSaveMobileSettingsDraft(TvMobileSettingsDraft draft) async {
    if (_savingMobileSubmittedDraft) {
      return;
    }

    _savingMobileSubmittedDraft = true;
    final accountSaver =
        widget.saveAccount ?? TvSettingsScreen.defaultSaveAccount;
    final imageSourceSaver = widget.saveDoubanImageSource ??
        TvSettingsScreen.defaultSaveDoubanImageSource;
    final adFilterSaver = widget.saveAdFilterEnabled ??
        TvSettingsScreen.defaultSaveAdFilterEnabled;
    final danmakuSaver =
        widget.saveDanmaku ?? TvSettingsScreen.defaultSaveDanmaku;

    try {
      final accountResult = await accountSaver(
        TvServerCredentials(
          serverUrl: draft.serverUrl,
          username: draft.username,
          password: draft.password,
        ),
      );
      if (!accountResult.success) {
        throw _TvSettingsAutoSaveException(accountResult.message);
      }

      // 账号配置成功后，再顺序保存同一份扫码草稿里的图片代理、去广告和弹幕配置。
      await imageSourceSaver(draft.doubanImageSource);
      await adFilterSaver(draft.adFilterEnabled);
      await danmakuSaver(draft.danmakuBaseApi, _danmakuSettings);

      if (!mounted) {
        return;
      }
      _showActionNotice(
        '手机配置已自动保存',
        type: _TvSettingsActionNoticeType.success,
      );
    } on _TvSettingsAutoSaveException catch (error) {
      if (!mounted) {
        return;
      }
      _showActionNotice(
        error.message,
        type: _TvSettingsActionNoticeType.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showActionNotice(
        '手机配置自动保存失败',
        type: _TvSettingsActionNoticeType.error,
      );
    } finally {
      _savingMobileSubmittedDraft = false;
    }
  }

  /// 在数据加载完成后派发首个设置项焦点。
  void _dispatchInitialFieldFocusIfNeeded({
    required bool isLoading,
  }) {
    if (_didDispatchInitialFieldFocus || isLoading) {
      return;
    }

    _didDispatchInitialFieldFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _regenerateQrFocusNode.requestFocus();
    });
  }

  /// 将加载到的数据写入输入框。
  void _applyLoadedData(TvSettingsData data) {
    if (_appliedLoadedData) {
      return;
    }
    _serverUrlController.text = data.serverUrl;
    _usernameController.text = data.username;
    _passwordController.text = data.password;
    _themeKey = TvThemePalette.fromKey(data.themeKey).key;
    _backgroundKey = TvThemeBackground.fromKey(data.backgroundKey).key;
    _focusEffectModeKey =
        TvFocusEffectMode.fromKey(data.focusEffectModeKey).key;
    _playerKernelKey = TvPlayerKernel.fromKey(data.playerKernelKey).key;
    _adFilterEnabled = data.adFilterEnabled;
    _doubanImageSource = data.doubanImageSource;
    _danmakuBaseApiController.text = data.danmakuBaseApi;
    _danmakuSettings = data.danmakuSettings;
    _appliedLoadedData = true;
    _syncMobileConfigDraft();
  }

  /// 请求焦点进入主题色选项组。
  ///
  /// 进入“图片与弹幕”区时优先回到上次停留的主题色选项，
  /// 避免默认遍历在 Wrap 布局里偶发把焦点丢回页面根节点。
  void _requestThemeOptionFocus() {
    TvFocusable.requestRememberedFocusForGroup('tv-setting-theme-主题色');
  }

  /// 请求焦点进入背景色选项组。
  ///
  /// 背景色与主题色一样是横向 Wrap 结构，单独补齐焦点记忆，
  /// 避免上下切换时跳回错误的彩色按钮或页面根节点。
  void _requestBackgroundOptionFocus() {
    TvFocusable.requestRememberedFocusForGroup('tv-setting-background-背景色');
  }

  /// 请求焦点进入焦点效果选项组。
  void _requestFocusEffectOptionFocus() {
    TvFocusable.requestRememberedFocusForGroup('tv-setting-focus-effect-焦点效果');
  }

  /// 请求焦点进入图片代理选项组。
  ///
  /// 主题色和图片代理都使用 Wrap 布局，显式补齐向下链路后，
  /// 可以避免上下切换时依赖默认几何遍历导致的焦点漂移。
  void _requestImageSourceOptionFocus() {
    TvFocusable.requestRememberedFocusForGroup('tv-setting-option-图片代理');
  }

  /// 请求焦点进入播放器内核选项组。
  void _requestPlayerKernelOptionFocus() {
    TvFocusable.requestRememberedFocusForGroup('tv-setting-option-播放器内核');
  }

  /// 保存服务器账号配置。
  Future<void> _saveAccount() async {
    setState(() {
      _savingAccount = true;
    });
    final saver = widget.saveAccount ?? TvSettingsScreen.defaultSaveAccount;
    try {
      final result = await saver(
        TvServerCredentials(
          serverUrl: _serverUrlController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _savingAccount = false;
      });
      _showActionNotice(
        result.message,
        type: result.success
            ? _TvSettingsActionNoticeType.success
            : _TvSettingsActionNoticeType.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingAccount = false;
      });
      _showActionNotice(
        '保存配置失败',
        type: _TvSettingsActionNoticeType.error,
      );
    }
  }

  /// 保存 TV 主题色配置。
  Future<void> _saveTheme(String themeKey) async {
    final nextThemeKey = TvThemePalette.fromKey(themeKey).key;
    final scopedService = TvTheme.maybeServiceOf(context);
    if (scopedService != null) {
      await scopedService.setThemeKey(nextThemeKey);
    } else {
      final saver = widget.saveTheme ?? TvSettingsScreen.defaultSaveTheme;
      await saver(nextThemeKey);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _themeKey = nextThemeKey;
    });
    _showToast('主题色已保存', TvThemePalette.fromKey(nextThemeKey).accent);
  }

  /// 保存 TV 页面背景色配置。
  Future<void> _saveBackground(String backgroundKey) async {
    final nextBackgroundKey = TvThemeBackground.fromKey(backgroundKey).key;
    final scopedService = TvTheme.maybeServiceOf(context);
    if (scopedService != null) {
      await scopedService.setBackgroundKey(nextBackgroundKey);
    } else {
      final saver =
          widget.saveBackground ?? TvSettingsScreen.defaultSaveBackground;
      await saver(nextBackgroundKey);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundKey = nextBackgroundKey;
    });
    _showToast(
      '背景色已保存',
      TvTheme.of(context).accent,
    );
  }

  /// 保存 TV 焦点效果配置。
  Future<void> _saveFocusEffect(String focusEffectModeKey) async {
    final nextModeKey = TvFocusEffectMode.fromKey(focusEffectModeKey).key;
    final scopedService = TvTheme.maybeServiceOf(context);
    if (scopedService != null) {
      await scopedService.setFocusEffectModeKey(nextModeKey);
    } else {
      final saver =
          widget.saveFocusEffect ?? TvSettingsScreen.defaultSaveFocusEffect;
      await saver(nextModeKey);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _focusEffectModeKey = nextModeKey;
    });
    _showToast(
      '焦点效果已保存',
      TvTheme.of(context).accent,
    );
  }

  /// 保存弹幕配置。
  Future<void> _saveDanmaku() async {
    setState(() {
      _savingDanmaku = true;
    });
    final saver = widget.saveDanmaku ?? TvSettingsScreen.defaultSaveDanmaku;
    try {
      await saver(_danmakuBaseApiController.text, _danmakuSettings);
      if (!mounted) {
        return;
      }
      setState(() {
        _savingDanmaku = false;
      });
      _showActionNotice(
        '弹幕配置已保存',
        type: _TvSettingsActionNoticeType.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingDanmaku = false;
      });
      _showActionNotice(
        '保存弹幕配置失败',
        type: _TvSettingsActionNoticeType.error,
      );
    }
  }

  /// 保存图片代理配置。
  Future<void> _saveDoubanImageSource(String imageSource) async {
    final saver = widget.saveDoubanImageSource ??
        TvSettingsScreen.defaultSaveDoubanImageSource;
    await saver(imageSource);
    if (!mounted) {
      return;
    }
    setState(() {
      _doubanImageSource = imageSource;
    });
    _syncMobileConfigDraft();
    _showToast('图片代理已保存', TvTheme.of(context).accent);
  }

  /// 保存 TV 播放器内核配置。
  Future<void> _savePlayerKernel(String playerKernelKey) async {
    final resolvedKernelKey = TvPlayerKernel.fromKey(playerKernelKey).key;
    final saver =
        widget.savePlayerKernel ?? TvSettingsScreen.defaultSavePlayerKernel;
    await saver(resolvedKernelKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _playerKernelKey = resolvedKernelKey;
    });
    _showToast(
      '播放器内核已切换为 ${TvPlayerKernel.fromKey(resolvedKernelKey).label}',
      TvTheme.of(context).accent,
    );
  }

  /// 保存自动去广告开关。
  Future<void> _saveAdFilterEnabled(bool enabled) async {
    final saver = widget.saveAdFilterEnabled ??
        TvSettingsScreen.defaultSaveAdFilterEnabled;
    await saver(enabled);
    if (!mounted) {
      return;
    }
    setState(() {
      _adFilterEnabled = enabled;
    });
    _syncMobileConfigDraft();
    _showToast(
      enabled ? '自动去广告已开启' : '自动去广告已关闭',
      TvTheme.of(context).accent,
    );
  }

  /// 清理全部非配置缓存并刷新缓存大小。
  Future<void> _clearAllCaches() async {
    setState(() {
      _clearingCaches = true;
    });

    final cleaner =
        widget.clearAllCaches ?? TvSettingsScreen.defaultClearAllCaches;
    try {
      await cleaner();
      if (!mounted) {
        return;
      }
      setState(() {
        _cacheSizeFuture =
            (widget.loadCacheSize ?? TvSettingsScreen.defaultLoadCacheSize)();
        _clearingCaches = false;
      });
      _showActionNotice(
        '缓存已清除',
        type: _TvSettingsActionNoticeType.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _clearingCaches = false;
      });
      _showActionNotice(
        '清除缓存失败',
        type: _TvSettingsActionNoticeType.error,
      );
    }
  }

  /// 展示操作反馈。
  void _showToast(String message, Color color) {
    // 轻量提示继续沿用普通 SnackBar，避免小开关和选项改成过重反馈。
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 展示三颗主操作按钮专用的页内提示。
  ///
  /// 成功提示保持明显的底部上浮反馈，失败提示则收敛成更紧凑的卡片，
  /// 避免遮住设置页主体内容。
  void _showActionNotice(
    String message, {
    required _TvSettingsActionNoticeType type,
  }) {
    _actionNoticeTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _actionNoticeMessage = message;
      _actionNoticeType = type;
    });

    // 固定 2 秒自动收起，避免长时间遮住底部操作区。
    _actionNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _actionNoticeMessage = null;
        _actionNoticeType = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 设置页作为独立路由时也要主动铺满全局 TV 背景，避免透明材质漏出默认底色。
    final pageBackgroundColor = TvTheme.backgroundOf(context).color;
    return TvBackHandler(
      autofocus: true,
      child: Material(
        color: pageBackgroundColor,
        child: FutureBuilder<TvSettingsData>(
          future: _settingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(
                  color: TvTheme.of(context).accent,
                ),
              );
            }

            _applyLoadedData(snapshot.data ?? TvSettingsData.empty());
            _dispatchInitialFieldFocusIfNeeded(
              isLoading: snapshot.connectionState != ConnectionState.done,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            TvLayout.pageHorizontalPadding,
                            _headerTopPadding,
                            TvLayout.pageHorizontalPadding,
                            0,
                          ),
                          child: _buildPinnedHeader(),
                        ),
                        const SizedBox(height: _headerBottomSpacing),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, scrollConstraints) {
                              // 追加半屏高度的底部缓冲，让末尾设置项也能滚到屏幕中线附近。
                              final bottomFocusBuffer =
                                  scrollConstraints.maxHeight * 0.5;
                              return SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  TvLayout.pageHorizontalPadding,
                                  20,
                                  TvLayout.pageHorizontalPadding,
                                  64 + bottomFocusBuffer,
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: _contentMaxWidth,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 先展示手机扫码区，方便用户进入设置页后先扫码在手机端填表。
                                        _buildMobileConfigSection(),
                                        const SizedBox(height: _panelSpacing),
                                        _buildAccountSection(),
                                        const SizedBox(height: _panelSpacing),
                                        _buildDanmakuSection(),
                                        const SizedBox(height: _panelSpacing),
                                        _buildCacheSection(),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    _buildActionNoticeOverlay(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 构建固定在顶部的页头。
  ///
  /// 设置页在内容滚动时始终保留标题和操作提示，
  /// 避免首焦点自动滚动后把“设置”页头直接推出视口。
  Widget _buildPinnedHeader() {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置',
              style: FontUtils.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '首焦点会自动进入服务器地址；输入框按确认编辑，开关和滑杆可直接用左右键调节。',
              style: FontUtils.poppins(
                fontSize: 15,
                color: const Color(0xFF98A2A8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设置页内部的主操作提示浮层。
  ///
  /// 提示挂在当前页面自己的 Stack 里，确保独立路由下也能立刻看见。
  Widget _buildActionNoticeOverlay() {
    final message = _actionNoticeMessage;
    final noticeType = _actionNoticeType;
    final bool hasNotice = message != null && noticeType != null;
    final bool isSuccess = noticeType == _TvSettingsActionNoticeType.success;
    const Color backgroundColor = Color(0xD9000000);
    final Color iconBackgroundColor =
        isSuccess ? TvTheme.of(context).accent : const Color(0xFFE05A5A);
    final double maxNoticeWidth = isSuccess ? 460 : 400;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TvLayout.pageHorizontalPadding,
              0,
              TvLayout.pageHorizontalPadding,
              34,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.16),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: child,
                    ),
                  );
                },
                child: !hasNotice
                    ? const SizedBox.shrink()
                    : ConstrainedBox(
                        key: ValueKey<String>(
                          'tv-settings-action-notice-$message-${noticeType.name}',
                        ),
                        constraints: BoxConstraints(maxWidth: maxNoticeWidth),
                        child: _TvSettingsActionNotice(
                          key: const ValueKey('tv-settings-action-notice'),
                          message: message,
                          backgroundColor: backgroundColor,
                          iconBackgroundColor: iconBackgroundColor,
                          icon: isSuccess
                              ? Icons.check_rounded
                              : Icons.error_outline_rounded,
                          compact: true,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建服务器配置区。
  Widget _buildAccountSection() {
    return _TvSettingsPanel(
      title: '服务器配置',
      description: '账号类字段默认停留在浏览态，按一次确认后才真正进入编辑。',
      children: [
        _TvTextField(
          fieldKey: const ValueKey('tv-settings-field-server-url'),
          label: '服务器地址',
          hintText: 'https://example.com',
          controller: _serverUrlController,
          browseFocusNode: _serverUrlBrowseFocusNode,
        ),
        const SizedBox(height: 14),
        _TvTextField(
          fieldKey: const ValueKey('tv-settings-field-username'),
          label: '账号',
          hintText: '请输入账号',
          controller: _usernameController,
          browseFocusNode: _usernameBrowseFocusNode,
        ),
        const SizedBox(height: 14),
        _TvTextField(
          fieldKey: const ValueKey('tv-settings-field-password'),
          label: '密码',
          hintText: '请输入密码',
          controller: _passwordController,
          obscureText: true,
          browseFocusNode: _passwordBrowseFocusNode,
        ),
        const SizedBox(height: 24),
        _TvActionButton(
          focusNode: _saveAccountFocusNode,
          label: _savingAccount ? '保存中...' : '保存配置',
          onPressed: _savingAccount ? null : _saveAccount,
          onArrowDown: _requestThemeOptionFocus,
        ),
      ],
    );
  }

  /// 构建弹幕配置区。
  Widget _buildDanmakuSection() {
    return _TvSettingsPanel(
      title: '图片与弹幕',
      description: '选项按钮可直接确认切换，开关与滑杆在获焦后可直接用左右键调整。',
      children: [
        _TvChipOptionRow<TvThemePalette>(
          label: '主题色',
          value: _themeKey,
          options: TvThemePalette.values,
          optionKeyBuilder: (option) => option.key,
          focusGroupKey: 'tv-setting-theme-主题色',
          onChanged: (option) => _saveTheme(option.key),
          onArrowUp: () => _saveAccountFocusNode.requestFocus(),
          onArrowDown: _requestBackgroundOptionFocus,
          chipStyleBuilder: _buildThemeOptionChip,
        ),
        const SizedBox(height: 18),
        _TvChipOptionRow<TvThemeBackground>(
          label: '背景色',
          value: _backgroundKey,
          options: TvThemeBackground.values,
          optionKeyBuilder: (option) => option.key,
          focusGroupKey: 'tv-setting-background-背景色',
          wrapSpacing: 14,
          chipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          chipBorderRadius: BorderRadius.circular(999),
          chipStyleBuilder: _buildBackgroundOptionChip,
          onChanged: (option) => _saveBackground(option.key),
          onArrowUp: _requestThemeOptionFocus,
          onArrowDown: _requestFocusEffectOptionFocus,
        ),
        const SizedBox(height: 18),
        _TvChipOptionRow<TvFocusEffectMode>(
          label: '焦点效果',
          value: _focusEffectModeKey,
          options: TvFocusEffectMode.values,
          optionKeyBuilder: (option) => option.key,
          focusGroupKey: 'tv-setting-focus-effect-焦点效果',
          onChanged: (option) => _saveFocusEffect(option.key),
          onArrowUp: _requestBackgroundOptionFocus,
          onArrowDown: _requestImageSourceOptionFocus,
          chipStyleBuilder: _buildFocusEffectOptionChip,
        ),
        const SizedBox(height: 18),
        _TvChipOptionRow<String>(
          label: '图片代理',
          value: _doubanImageSource,
          options: TvMobileSettingsDraft.availableDoubanImageSources,
          optionKeyBuilder: (option) => option,
          focusGroupKey: 'tv-setting-option-图片代理',
          onChanged: _saveDoubanImageSource,
          onArrowUp: _requestFocusEffectOptionFocus,
          onArrowDown: _requestPlayerKernelOptionFocus,
          chipStyleBuilder: _buildPlainOptionChip,
        ),
        const SizedBox(height: 18),
        _TvChipOptionRow<TvPlayerKernel>(
          label: '播放器内核',
          value: _playerKernelKey,
          options: TvPlayerKernel.values,
          optionKeyBuilder: (option) => option.key,
          focusGroupKey: 'tv-setting-option-播放器内核',
          onChanged: (option) => _savePlayerKernel(option.key),
          onArrowUp: _requestImageSourceOptionFocus,
          onArrowDown: () => _adFilterFocusNode.requestFocus(),
          chipStyleBuilder: _buildPlayerKernelOptionChip,
        ),
        const SizedBox(height: 18),
        _TvSwitchRow(
          focusNode: _adFilterFocusNode,
          switchKey: const ValueKey('tv-settings-ad-filter-switch'),
          label: '自动去广告',
          value: _adFilterEnabled,
          onChanged: _saveAdFilterEnabled,
          onArrowUp: () => TvFocusable.requestRememberedFocusForGroup(
            'tv-setting-option-图片代理',
          ),
          onArrowDown: () => _danmakuBaseApiBrowseFocusNode.requestFocus(),
        ),
        const SizedBox(height: 18),
        _TvTextField(
          fieldKey: const ValueKey('tv-settings-field-danmaku-base-api'),
          label: '弹幕服务器地址',
          hintText: 'https://danmaku.example.com/',
          controller: _danmakuBaseApiController,
          browseFocusNode: _danmakuBaseApiBrowseFocusNode,
          onArrowUp: () => _adFilterFocusNode.requestFocus(),
          onArrowDown: () => _danmakuEnabledFocusNode.requestFocus(),
        ),
        const SizedBox(height: 18),
        _TvSwitchRow(
          focusNode: _danmakuEnabledFocusNode,
          switchKey: const ValueKey('tv-settings-danmaku-enabled-switch'),
          label: '弹幕开关',
          value: _danmakuSettings.enabled,
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(enabled: value);
            });
          },
          onArrowUp: () => _danmakuBaseApiBrowseFocusNode.requestFocus(),
          onArrowDown: () => _danmakuOpacityFocusNode.requestFocus(),
        ),
        _TvSliderRow(
          focusNode: _danmakuOpacityFocusNode,
          label: '不透明度',
          value: _danmakuSettings.opacity,
          min: 0.1,
          max: 1,
          step: 0.05,
          valueLabel: '${(_danmakuSettings.opacity * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(opacity: value);
            });
          },
          onArrowUp: () => _danmakuEnabledFocusNode.requestFocus(),
          onArrowDown: () => _danmakuScaleFocusNode.requestFocus(),
        ),
        _TvSliderRow(
          focusNode: _danmakuScaleFocusNode,
          label: '字体缩放',
          value: _danmakuSettings.scale,
          min: 0.5,
          max: 2,
          step: 0.1,
          valueLabel: '${_danmakuSettings.scale.toStringAsFixed(1)}x',
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(scale: value);
            });
          },
          onArrowUp: () => _danmakuOpacityFocusNode.requestFocus(),
          onArrowDown: () => _danmakuDisplayAreaFocusNode.requestFocus(),
        ),
        _TvSliderRow(
          focusNode: _danmakuDisplayAreaFocusNode,
          label: '显示区域',
          value: _danmakuSettings.displayArea,
          min: 0.25,
          max: 1,
          step: 0.05,
          valueLabel: '${(_danmakuSettings.displayArea * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(displayArea: value);
            });
          },
          onArrowUp: () => _danmakuScaleFocusNode.requestFocus(),
          onArrowDown: () => _danmakuPreventOverlapFocusNode.requestFocus(),
        ),
        _TvSwitchRow(
          focusNode: _danmakuPreventOverlapFocusNode,
          label: '防止重叠',
          value: _danmakuSettings.preventOverlap,
          onChanged: (value) {
            setState(() {
              _danmakuSettings =
                  _danmakuSettings.copyWith(preventOverlap: value);
            });
          },
          onArrowUp: () => _danmakuDisplayAreaFocusNode.requestFocus(),
          onArrowDown: () => _danmakuSyncVideoSpeedFocusNode.requestFocus(),
        ),
        _TvSwitchRow(
          focusNode: _danmakuSyncVideoSpeedFocusNode,
          label: '同步视频速度',
          value: _danmakuSettings.syncVideoSpeed,
          onChanged: (value) {
            setState(() {
              _danmakuSettings =
                  _danmakuSettings.copyWith(syncVideoSpeed: value);
            });
          },
          onArrowUp: () => _danmakuPreventOverlapFocusNode.requestFocus(),
          onArrowDown: () => _saveDanmakuFocusNode.requestFocus(),
        ),
        const SizedBox(height: 22),
        _TvActionButton(
          focusNode: _saveDanmakuFocusNode,
          label: _savingDanmaku ? '保存中...' : '保存弹幕配置',
          onPressed: _savingDanmaku ? null : _saveDanmaku,
          onArrowUp: () => _danmakuSyncVideoSpeedFocusNode.requestFocus(),
          onArrowDown: () => _clearCachesFocusNode.requestFocus(),
        ),
      ],
    );
  }

  /// 构建缓存管理区。
  Widget _buildCacheSection() {
    return _TvSettingsPanel(
      title: '缓存管理',
      description: '清缓存不会影响账号、图片代理和弹幕配置，只会处理运行期缓存文件。',
      children: [
        FutureBuilder<int>(
          future: _cacheSizeFuture,
          builder: (context, snapshot) {
            final sizeLabel = snapshot.connectionState == ConnectionState.done
                ? AppCacheService.formatBytes(snapshot.data ?? 0)
                : '计算中...';
            return _TvValueRow(
              label: '缓存占用',
              value: sizeLabel,
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '空间低于 500MB 时会自动清理图片缓存，并暂时不写入新的图片磁盘缓存。',
          style: FontUtils.poppins(
            fontSize: 13,
            color: const Color(0xFF98A2A8),
          ),
        ),
        const SizedBox(height: 18),
        _TvActionButton(
          focusNode: _clearCachesFocusNode,
          label: _clearingCaches ? '清理中...' : '清除所有缓存',
          onPressed: _clearingCaches ? null : _clearAllCaches,
          onArrowUp: () => _saveDanmakuFocusNode.requestFocus(),
        ),
      ],
    );
  }

  /// 构建手机扫码配置区。
  Widget _buildMobileConfigSection() {
    final session = _mobileConfigBridgeSession;
    final shareUri = session?.shareUri;
    return _TvSettingsPanel(
      title: '手机扫码配置',
      description: '手机和电视连接同一局域网后，扫码可在手机上填写服务器、图片代理和弹幕地址，提交后会回填到电视表单里。',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalLayout = constraints.maxWidth < 980;
            final qrCard = _buildMobileConfigQrCard(shareUri);
            final detailCard = _buildMobileConfigDetailCard(
              session: session,
              shareUri: shareUri,
            );
            if (useVerticalLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  qrCard,
                  const SizedBox(height: 18),
                  detailCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                qrCard,
                const SizedBox(width: 22),
                Expanded(child: detailCard),
              ],
            );
          },
        ),
      ],
    );
  }

  /// 构建手机扫码区左侧二维码卡片。
  Widget _buildMobileConfigQrCard(Uri? shareUri) {
    final palette = TvTheme.of(context);
    return Container(
      width: 252,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1112),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF293136)),
      ),
      child: Column(
        children: [
          Container(
            width: 220,
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: shareUri == null
                ? Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: palette.disabledFill,
                  )
                : QrImageView(
                    data: shareUri.toString(),
                    size: 204,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF111111),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF111111),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            shareUri == null ? '等待局域网地址' : '使用手机扫码打开配置页',
            textAlign: TextAlign.center,
            style: FontUtils.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建手机扫码区右侧说明卡片。
  Widget _buildMobileConfigDetailCard({
    required TvMobileSettingsBridgeSession? session,
    required Uri? shareUri,
  }) {
    final palette = TvTheme.of(context);
    final shareAddress = _formatShareAddress(shareUri);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手机端可编辑字段',
          style: FontUtils.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '服务器地址、账号、密码、图片代理、自动去广告、弹幕服务器地址。',
          style: FontUtils.poppins(
            fontSize: 14,
            color: const Color(0xFFB6C1C6),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1112),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF293136)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '扫码地址',
                style: FontUtils.poppins(
                  fontSize: 13,
                  color: const Color(0xFF98A2A8),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                shareAddress ?? '当前未生成可供手机访问的局域网地址',
                style: FontUtils.poppins(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '会话状态',
                style: FontUtils.poppins(
                  fontSize: 13,
                  color: const Color(0xFF98A2A8),
                ),
              ),
              const SizedBox(height: 8),
              if (session == null)
                Text(
                  '手机配置服务启动中...',
                  style: FontUtils.poppins(
                    fontSize: 15,
                    color: const Color(0xFFE6A35C),
                  ),
                )
              else
                ValueListenableBuilder<String>(
                  valueListenable: session.statusNotifier,
                  builder: (context, status, child) {
                    return Text(
                      status,
                      style: FontUtils.poppins(
                        fontSize: 15,
                        color: shareUri == null
                            ? const Color(0xFFE6A35C)
                            : palette.accent,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 260,
          child: _TvActionButton(
            focusNode: _regenerateQrFocusNode,
            label: '重新生成二维码',
            onPressed: _restartMobileConfigBridge,
            onArrowDown: () => _serverUrlBrowseFocusNode.requestFocus(),
          ),
        ),
      ],
    );
  }

  /// 将扫码地址格式化为更短的 `ip:端口` 形式，方便人工核对。
  String? _formatShareAddress(Uri? shareUri) {
    if (shareUri == null) {
      return null;
    }
    final host = shareUri.host.trim();
    if (host.isEmpty) {
      return null;
    }
    return '$host:${shareUri.port}';
  }

  /// 构建主题色选项芯片。
  ///
  /// 主题色使用主色块作为选中背景，并在左侧保留圆点预览，
  /// 让用户无需离开设置页也能快速区分两个主题方案。
  _TvChipOptionStyle _buildThemeOptionChip(
    BuildContext context,
    TvThemePalette option,
    bool selected,
    bool hasFocus,
  ) {
    return _TvChipOptionStyle(
      backgroundColor: selected ? option.accent : const Color(0xFF0E1112),
      borderColor: hasFocus
          ? Colors.white
          : selected
              ? option.accent
              : const Color(0xFF293136),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: option.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            option.label,
            style: FontUtils.poppins(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? option.selectedText : const Color(0xFFD9E2E0),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建背景色选项芯片。
  ///
  /// 背景色使用胶囊型边框和圆点预览，确保和主题色按钮维持
  /// 不同语义的视觉分层，但仍复用同一套焦点与 Wrap 逻辑。
  _TvChipOptionStyle _buildBackgroundOptionChip(
    BuildContext context,
    TvThemeBackground option,
    bool selected,
    bool hasFocus,
  ) {
    final palette = TvTheme.of(context);
    return _TvChipOptionStyle(
      backgroundColor: const Color(0xFF0E1112),
      borderColor: hasFocus
          ? Colors.white
          : selected
              ? palette.accent
              : const Color(0xFF293136),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.color,
              border: Border.all(
                color: selected ? palette.accent : Colors.white24,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            option.label,
            style: FontUtils.poppins(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFFD9E2E0),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建普通文案选项芯片。
  ///
  /// 图片代理等纯文本场景沿用主题色按钮的主色选中态，
  /// 保持设置页的视觉统一与焦点反馈一致。
  _TvChipOptionStyle _buildPlainOptionChip(
    BuildContext context,
    String option,
    bool selected,
    bool hasFocus,
  ) {
    final palette = TvTheme.of(context);
    return _TvChipOptionStyle(
      backgroundColor: selected ? palette.accent : const Color(0xFF0E1112),
      borderColor: hasFocus
          ? Colors.white
          : selected
              ? palette.accent
              : const Color(0xFF293136),
      child: Text(
        option,
        style: FontUtils.poppins(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? palette.selectedText : const Color(0xFFD9E2E0),
        ),
      ),
    );
  }

  /// 构建播放器内核选项芯片。
  _TvChipOptionStyle _buildPlayerKernelOptionChip(
    BuildContext context,
    TvPlayerKernel option,
    bool selected,
    bool hasFocus,
  ) {
    return _buildPlainOptionChip(
      context,
      option.label,
      selected,
      hasFocus,
    );
  }

  /// 构建焦点效果选项芯片。
  _TvChipOptionStyle _buildFocusEffectOptionChip(
    BuildContext context,
    TvFocusEffectMode option,
    bool selected,
    bool hasFocus,
  ) {
    return _buildPlainOptionChip(
      context,
      option.label,
      selected,
      hasFocus,
    );
  }
}

/// TV 设置页主操作提示卡。
class _TvSettingsActionNotice extends StatelessWidget {
  /// 创建 TV 设置页主操作提示卡。
  const _TvSettingsActionNotice({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.icon,
    this.compact = false,
  });

  /// 提示正文。
  final String message;

  /// 卡片背景色。
  final Color backgroundColor;

  /// 图标底色。
  final Color iconBackgroundColor;

  /// 状态图标。
  final IconData icon;

  /// 是否使用紧凑布局。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double iconBoxSize = compact ? 34 : 48;
    final double iconSize = compact ? 20 : 28;
    final EdgeInsets contentPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 22, vertical: 16);
    return Container(
      key: const ValueKey('tv-settings-action-notice-surface'),
      constraints: BoxConstraints(minHeight: compact ? 54 : 86),
      padding: contentPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
            ),
          ),
          SizedBox(width: compact ? 14 : 16),
          Flexible(
            child: Text(
              message,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: FontUtils.poppins(
                fontSize: compact ? 15 : 16,
                fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFFE7F0EC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手机扫码自动保存失败异常。
class _TvSettingsAutoSaveException implements Exception {
  /// 创建手机扫码自动保存失败异常。
  const _TvSettingsAutoSaveException(this.message);

  /// 失败提示文案。
  final String message;
}

/// TV 设置值展示行。
class _TvValueRow extends StatelessWidget {
  /// 创建 TV 设置值展示行。
  const _TvValueRow({
    required this.label,
    required this.value,
  });

  /// 设置项文案。
  final String label;

  /// 当前值文案。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 17,
              color: const Color(0xFFD9E2E0),
            ),
          ),
        ),
        Text(
          value,
          style: FontUtils.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// TV 设置分组面板。
class _TvSettingsPanel extends StatelessWidget {
  /// 创建 TV 设置分组面板。
  const _TvSettingsPanel({
    required this.title,
    this.description,
    required this.children,
  });

  /// 分组标题。
  final String title;

  /// 分组说明。
  final String? description;

  /// 分组内容。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15191B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF293136)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FontUtils.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: FontUtils.poppins(
                fontSize: 14,
                color: const Color(0xFF98A2A8),
              ),
            ),
          ],
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

/// TV 设置输入框。
class _TvTextField extends StatefulWidget {
  /// 创建 TV 设置输入框。
  const _TvTextField({
    this.fieldKey,
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.browseFocusNode,
    this.onArrowUp,
    this.onArrowDown,
  });

  /// 焦点容器 Key。
  final Key? fieldKey;

  /// 输入框标签。
  final String label;

  /// 输入提示。
  final String hintText;

  /// 输入控制器。
  final TextEditingController controller;

  /// 是否隐藏输入内容。
  final bool obscureText;

  /// 浏览态焦点节点。
  ///
  /// 浏览态负责承接 TV 遥控器焦点，真正编辑时再切换到内部文本焦点。
  final FocusNode? browseFocusNode;

  /// 浏览态上方向键回调。
  final VoidCallback? onArrowUp;

  /// 浏览态下方向键回调。
  final VoidCallback? onArrowDown;

  @override
  State<_TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<_TvTextField> {
  /// 内部创建的浏览态焦点节点。
  final FocusNode _ownedBrowseFocusNode = FocusNode();

  /// 编辑态输入焦点节点。
  final FocusNode _editFocusNode = FocusNode();

  /// 当前是否进入编辑态。
  bool _isEditing = false;

  /// 当前实际使用的浏览态焦点节点。
  FocusNode get _effectiveBrowseFocusNode =>
      widget.browseFocusNode ?? _ownedBrowseFocusNode;

  @override
  void initState() {
    super.initState();
    _editFocusNode.addListener(_handleEditingFocusChange);
  }

  @override
  void dispose() {
    _editFocusNode.removeListener(_handleEditingFocusChange);
    _ownedBrowseFocusNode.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  /// 进入编辑态并主动唤起系统键盘。
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _editFocusNode.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  /// 编辑态失焦后回退到浏览态。
  void _handleEditingFocusChange() {
    if (_editFocusNode.hasFocus || !_isEditing) {
      return;
    }
    _finishEditing(restoreBrowseFocus: false);
  }

  /// 处理编辑态按键。
  ///
  /// 遥控器在编辑态下按确认或返回时，都会先结束输入并回到浏览态。
  KeyEventResult _handleEditingKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (TvBackIntent.isBackKey(event.logicalKey) ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _finishEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 完成编辑后保留浏览态焦点并关闭键盘。
  void _finishEditing({
    bool restoreBrowseFocus = true,
  }) {
    if (!_isEditing) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!restoreBrowseFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _effectiveBrowseFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: FontUtils.poppins(
            fontSize: 15,
            color: const Color(0xFF98A2A8),
          ),
        ),
        const SizedBox(height: 8),
        TvFocusable(
          key: widget.fieldKey,
          focusNode: _effectiveBrowseFocusNode,
          onPressed: _startEditing,
          onArrowUp: widget.onArrowUp,
          onArrowDown: widget.onArrowDown,
          focusScrollAlignment: _tvSettingsFocusScrollAlignment,
          builder: (context, hasFocus) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1112),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus ? Colors.white : const Color(0xFF293136),
                  width: hasFocus ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: IgnorePointer(
                      ignoring: !_isEditing,
                      child: ExcludeFocus(
                        excluding: !_isEditing,
                        child: Focus(
                          onKeyEvent: _handleEditingKeyEvent,
                          child: TextField(
                            focusNode: _editFocusNode,
                            controller: widget.controller,
                            obscureText: widget.obscureText,
                            readOnly: !_isEditing,
                            showCursor: _isEditing,
                            textInputAction: TextInputAction.done,
                            onEditingComplete: () => _finishEditing(),
                            onSubmitted: (_) => _finishEditing(),
                            style: FontUtils.poppins(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              hintText: widget.hintText,
                              hintStyle: FontUtils.poppins(
                                fontSize: 16,
                                color: const Color(0xFF59656C),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: hasFocus
                            ? palette.focus.withValues(alpha: 0.18)
                            : const Color(0xFF151C1F),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '按确认编辑',
                        style: FontUtils.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasFocus
                              ? palette.focus
                              : const Color(0xFF98A2A8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// TV 设置通用芯片选项行。
///
/// 统一承载主题色、背景色和图片代理这类 Wrap 结构的设置项，
/// 把焦点记忆、方向链和滚动对齐收口到同一处，避免后续分叉维护。
class _TvChipOptionRow<T> extends StatelessWidget {
  /// 创建 TV 设置通用芯片选项行。
  const _TvChipOptionRow({
    required this.label,
    required this.value,
    required this.options,
    required this.optionKeyBuilder,
    required this.focusGroupKey,
    required this.onChanged,
    required this.chipStyleBuilder,
    this.onArrowUp,
    this.onArrowDown,
    this.wrapSpacing = 10,
    this.wrapRunSpacing = 10,
    this.chipPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
    this.chipConstraints = const BoxConstraints(minHeight: 42),
    this.chipBorderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  /// 设置项标签。
  final String label;

  /// 当前选中值标识。
  final String value;

  /// 可选值列表。
  final List<T> options;

  /// 选项唯一标识构建器。
  final String Function(T option) optionKeyBuilder;

  /// 焦点记忆与重复节流分组标识。
  final String focusGroupKey;

  /// 选项变更回调。
  final ValueChanged<T> onChanged;

  /// 单个芯片样式构建器。
  final _TvChipOptionStyle Function(
    BuildContext context,
    T option,
    bool selected,
    bool hasFocus,
  ) chipStyleBuilder;

  /// 所有选项统一的上方向键回调。
  final VoidCallback? onArrowUp;

  /// 所有选项统一的下方向键回调。
  final VoidCallback? onArrowDown;

  /// Wrap 横向间距。
  final double wrapSpacing;

  /// Wrap 纵向间距。
  final double wrapRunSpacing;

  /// 芯片内边距。
  final EdgeInsetsGeometry chipPadding;

  /// 芯片尺寸约束。
  final BoxConstraints chipConstraints;

  /// 芯片圆角配置。
  final BorderRadiusGeometry chipBorderRadius;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FontUtils.poppins(
            fontSize: 15,
            color: const Color(0xFF98A2A8),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: wrapSpacing,
          runSpacing: wrapRunSpacing,
          children: options.map((option) {
            final selected = optionKeyBuilder(option) == value;
            return TvFocusable(
              directionalRepeatThrottleGroupKey: focusGroupKey,
              focusMemoryGroupKey: focusGroupKey,
              onPressed: () => onChanged(option),
              onArrowUp: onArrowUp,
              onArrowDown: onArrowDown,
              focusScrollAlignment: _tvSettingsFocusScrollAlignment,
              builder: (context, hasFocus) {
                final style = chipStyleBuilder(
                  context,
                  option,
                  selected,
                  hasFocus,
                );
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  constraints: chipConstraints,
                  padding: chipPadding,
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: chipBorderRadius,
                    border: Border.all(
                      color: style.borderColor,
                      width: hasFocus ? 2 : 1,
                    ),
                  ),
                  child: style.child,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// TV 设置通用芯片样式。
///
/// 把背景色、描边色与内容本体拆成轻量样式对象，
/// 让通用行统一绘制外壳，不同业务芯片只关心自身内容差异。
class _TvChipOptionStyle {
  /// 创建 TV 设置通用芯片样式。
  const _TvChipOptionStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  /// 芯片背景色。
  final Color backgroundColor;

  /// 芯片描边色。
  final Color borderColor;

  /// 芯片主体内容。
  final Widget child;
}

/// TV 设置操作按钮。
class _TvActionButton extends StatelessWidget {
  /// 创建 TV 设置操作按钮。
  const _TvActionButton({
    this.focusNode,
    required this.label,
    required this.onPressed,
    this.onArrowUp,
    this.onArrowDown,
  });

  /// 按钮焦点节点。
  final FocusNode? focusNode;

  /// 按钮文案。
  final String label;

  /// 点击回调。
  final VoidCallback? onPressed;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      onPressed: onPressed,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      focusScrollAlignment: _tvSettingsFocusScrollAlignment,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onPressed == null ? palette.disabledFill : palette.accent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: palette.selectedText,
            ),
          ),
        );
      },
    );
  }
}

/// TV 设置开关行。
class _TvSwitchRow extends StatelessWidget {
  /// 创建 TV 设置开关行。
  const _TvSwitchRow({
    this.focusNode,
    this.switchKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onArrowUp,
    this.onArrowDown,
  });

  /// 行级焦点节点。
  final FocusNode? focusNode;

  /// 开关键。
  final Key? switchKey;

  /// 设置项文案。
  final String label;

  /// 当前开关值。
  final bool value;

  /// 开关变更回调。
  final ValueChanged<bool> onChanged;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      onPressed: () => onChanged(!value),
      onArrowLeft: value ? () => onChanged(false) : null,
      onArrowRight: !value ? () => onChanged(true) : null,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      focusScrollAlignment: _tvSettingsFocusScrollAlignment,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1112),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus ? Colors.white : const Color(0xFF293136),
              width: hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: FontUtils.poppins(
                        fontSize: 17,
                        color: const Color(0xFFD9E2E0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value ? '当前已开启，可按左键关闭' : '当前已关闭，可按右键开启',
                      style: FontUtils.poppins(
                        fontSize: 13,
                        color: const Color(0xFF98A2A8),
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeFocus(
                child: Switch(
                  key: switchKey,
                  value: value,
                  activeThumbColor: palette.accent,
                  activeTrackColor: palette.accent.withValues(alpha: 0.32),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// TV 设置滑杆行。
class _TvSliderRow extends StatelessWidget {
  /// 创建 TV 设置滑杆行。
  const _TvSliderRow({
    this.focusNode,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.valueLabel,
    required this.onChanged,
    this.onArrowUp,
    this.onArrowDown,
  });

  /// 行级焦点节点。
  final FocusNode? focusNode;

  /// 设置项文案。
  final String label;

  /// 当前值。
  final double value;

  /// 最小值。
  final double min;

  /// 最大值。
  final double max;

  /// 遥控器每次左右键调整的步进。
  final double step;

  /// 当前值文案。
  final String valueLabel;

  /// 值变更回调。
  final ValueChanged<double> onChanged;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    final safeValue = value.clamp(min, max).toDouble();
    return TvFocusable(
      focusNode: focusNode,
      onArrowLeft: () {
        final nextValue = (safeValue - step).clamp(min, max).toDouble();
        if (nextValue == safeValue) {
          return;
        }
        onChanged(nextValue);
      },
      onArrowRight: () {
        final nextValue = (safeValue + step).clamp(min, max).toDouble();
        if (nextValue == safeValue) {
          return;
        }
        onChanged(nextValue);
      },
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      focusScrollAlignment: _tvSettingsFocusScrollAlignment,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1112),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus ? Colors.white : const Color(0xFF293136),
              width: hasFocus ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: FontUtils.poppins(
                        fontSize: 17,
                        color: const Color(0xFFD9E2E0),
                      ),
                    ),
                  ),
                  Text(
                    valueLabel,
                    style: FontUtils.poppins(
                      fontSize: 15,
                      color: const Color(0xFF98A2A8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '左右键调节数值',
                style: FontUtils.poppins(
                  fontSize: 13,
                  color: const Color(0xFF98A2A8),
                ),
              ),
              ExcludeFocus(
                child: Slider(
                  value: safeValue,
                  min: min,
                  max: max,
                  activeColor: palette.accent,
                  inactiveColor: palette.disabledFill,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
