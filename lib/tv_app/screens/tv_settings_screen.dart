import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/services/app_cache_service.dart';
import 'package:selene/services/danmaku_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_account_config_service.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';

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

/// TV 主题色保存函数。
typedef TvThemeSaver = Future<void> Function(String themeKey);

/// TV 缓存大小加载函数。
typedef TvCacheSizeLoader = Future<int> Function();

/// TV 缓存清理函数。
typedef TvCacheCleaner = Future<void> Function();

/// TV 设置页聚合数据。
class TvSettingsData {
  /// 创建 TV 设置页聚合数据。
  const TvSettingsData({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.themeKey = TvThemePalette.ivyGreenKey,
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
      themeKey: TvThemePalette.ivyGreenKey,
      doubanImageSource: '直连',
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
    this.saveDoubanImageSource,
    this.saveDanmaku,
    this.loadCacheSize,
    this.clearAllCaches,
  });

  /// 设置加载函数。
  final TvSettingsLoader? loadSettings;

  /// 账号保存函数。
  final TvAccountSaver? saveAccount;

  /// 主题色保存函数。
  final TvThemeSaver? saveTheme;

  /// 图片代理保存函数。
  final TvImageSourceSaver? saveDoubanImageSource;

  /// 弹幕设置保存函数。
  final TvDanmakuSaver? saveDanmaku;

  /// 缓存大小加载函数。
  final TvCacheSizeLoader? loadCacheSize;

  /// 清理全部缓存函数。
  final TvCacheCleaner? clearAllCaches;

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

  /// 默认主题色保存逻辑。
  static Future<void> defaultSaveTheme(String themeKey) {
    return TvThemeService.saveThemeKey(themeKey);
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
  /// 服务器地址输入控制器。
  final TextEditingController _serverUrlController = TextEditingController();

  /// 账号输入控制器。
  final TextEditingController _usernameController = TextEditingController();

  /// 密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 弹幕服务器输入控制器。
  final TextEditingController _danmakuBaseApiController =
      TextEditingController();

  /// 设置加载任务。
  late Future<TvSettingsData> _settingsFuture;

  /// 缓存大小加载任务。
  late Future<int> _cacheSizeFuture;

  /// 当前弹幕设置。
  DanmakuSettings _danmakuSettings = const DanmakuSettings();

  /// 当前豆瓣图片代理。
  String _doubanImageSource = '直连';

  /// 当前 TV 主题色标识。
  String _themeKey = TvThemePalette.ivyGreen.key;

  /// 是否已把加载数据同步到输入框。
  bool _appliedLoadedData = false;

  /// 是否正在保存账号。
  bool _savingAccount = false;

  /// 是否正在保存弹幕设置。
  bool _savingDanmaku = false;

  /// 是否正在清理缓存。
  bool _clearingCaches = false;

  @override
  void initState() {
    super.initState();
    _settingsFuture =
        (widget.loadSettings ?? TvSettingsScreen.defaultLoadSettings)();
    _cacheSizeFuture =
        (widget.loadCacheSize ?? TvSettingsScreen.defaultLoadCacheSize)();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _danmakuBaseApiController.dispose();
    super.dispose();
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
    _doubanImageSource = data.doubanImageSource;
    _danmakuBaseApiController.text = data.danmakuBaseApi;
    _danmakuSettings = data.danmakuSettings;
    _appliedLoadedData = true;
  }

  /// 保存服务器账号配置。
  Future<void> _saveAccount() async {
    setState(() {
      _savingAccount = true;
    });
    final saver = widget.saveAccount ?? TvSettingsScreen.defaultSaveAccount;
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
    _showToast(
      result.message,
      result.success ? TvTheme.of(context).accent : const Color(0xFFE05A5A),
    );
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

  /// 保存弹幕配置。
  Future<void> _saveDanmaku() async {
    setState(() {
      _savingDanmaku = true;
    });
    final saver = widget.saveDanmaku ?? TvSettingsScreen.defaultSaveDanmaku;
    await saver(_danmakuBaseApiController.text, _danmakuSettings);
    if (!mounted) {
      return;
    }
    setState(() {
      _savingDanmaku = false;
    });
    _showToast('弹幕配置已保存', TvTheme.of(context).accent);
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
    _showToast('图片代理已保存', TvTheme.of(context).accent);
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
      _showToast('缓存已清除', TvTheme.of(context).accent);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _clearingCaches = false;
      });
      _showToast('清除缓存失败', const Color(0xFFE05A5A));
    }
  }

  /// 展示操作反馈。
  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
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

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TvLayout.pageHorizontalPadding,
              8,
              TvLayout.pageHorizontalPadding,
              64,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAccountSection()),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    children: [
                      _buildDanmakuSection(),
                      const SizedBox(height: 28),
                      _buildCacheSection(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建服务器配置区。
  Widget _buildAccountSection() {
    return _TvSettingsPanel(
      title: '服务器配置',
      children: [
        _TvTextField(
          label: '服务器地址',
          hintText: 'https://example.com',
          controller: _serverUrlController,
        ),
        const SizedBox(height: 14),
        _TvTextField(
          label: '账号',
          hintText: '请输入账号',
          controller: _usernameController,
        ),
        const SizedBox(height: 14),
        _TvTextField(
          label: '密码',
          hintText: '请输入密码',
          controller: _passwordController,
          obscureText: true,
        ),
        const SizedBox(height: 24),
        _TvActionButton(
          label: _savingAccount ? '保存中...' : '保存配置',
          onPressed: _savingAccount ? null : _saveAccount,
        ),
      ],
    );
  }

  /// 构建弹幕配置区。
  Widget _buildDanmakuSection() {
    return _TvSettingsPanel(
      title: '图片与弹幕',
      children: [
        _TvThemeOptionRow(
          label: '主题色',
          value: _themeKey,
          options: TvThemePalette.values,
          onChanged: _saveTheme,
        ),
        const SizedBox(height: 18),
        _TvOptionRow(
          label: '图片代理',
          value: _doubanImageSource,
          options: const [
            '直连',
            '豆瓣官方精品 CDN',
            '豆瓣 CDN By CMLiussss（腾讯云）',
            '豆瓣 CDN By CMLiussss（阿里云）',
          ],
          onChanged: _saveDoubanImageSource,
        ),
        const SizedBox(height: 18),
        _TvTextField(
          label: '弹幕服务器地址',
          hintText: 'https://danmaku.example.com/',
          controller: _danmakuBaseApiController,
        ),
        const SizedBox(height: 18),
        _TvSwitchRow(
          label: '弹幕开关',
          value: _danmakuSettings.enabled,
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(enabled: value);
            });
          },
        ),
        _TvSliderRow(
          label: '不透明度',
          value: _danmakuSettings.opacity,
          min: 0.1,
          max: 1,
          valueLabel: '${(_danmakuSettings.opacity * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(opacity: value);
            });
          },
        ),
        _TvSliderRow(
          label: '字体缩放',
          value: _danmakuSettings.scale,
          min: 0.5,
          max: 2,
          valueLabel: '${_danmakuSettings.scale.toStringAsFixed(1)}x',
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(scale: value);
            });
          },
        ),
        _TvSliderRow(
          label: '显示区域',
          value: _danmakuSettings.displayArea,
          min: 0.25,
          max: 1,
          valueLabel: '${(_danmakuSettings.displayArea * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _danmakuSettings = _danmakuSettings.copyWith(displayArea: value);
            });
          },
        ),
        _TvSwitchRow(
          label: '防止重叠',
          value: _danmakuSettings.preventOverlap,
          onChanged: (value) {
            setState(() {
              _danmakuSettings =
                  _danmakuSettings.copyWith(preventOverlap: value);
            });
          },
        ),
        _TvSwitchRow(
          label: '同步视频速度',
          value: _danmakuSettings.syncVideoSpeed,
          onChanged: (value) {
            setState(() {
              _danmakuSettings =
                  _danmakuSettings.copyWith(syncVideoSpeed: value);
            });
          },
        ),
        const SizedBox(height: 22),
        _TvActionButton(
          label: _savingDanmaku ? '保存中...' : '保存弹幕配置',
          onPressed: _savingDanmaku ? null : _saveDanmaku,
        ),
      ],
    );
  }

  /// 构建缓存管理区。
  Widget _buildCacheSection() {
    return _TvSettingsPanel(
      title: '缓存管理',
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
          label: _clearingCaches ? '清理中...' : '清除所有缓存',
          onPressed: _clearingCaches ? null : _clearAllCaches,
        ),
      ],
    );
  }
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
    required this.children,
  });

  /// 分组标题。
  final String title;

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
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
  });

  /// 输入框标签。
  final String label;

  /// 输入提示。
  final String hintText;

  /// 输入控制器。
  final TextEditingController controller;

  /// 是否隐藏输入内容。
  final bool obscureText;

  @override
  State<_TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<_TvTextField> {
  /// 输入框焦点节点。
  final FocusNode _focusNode = FocusNode();

  /// 当前是否进入编辑态。
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  /// 焦点离开输入框后退出编辑态，避免下次移入时直接弹键盘。
  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      TvFocusScroll.ensureVisible(context);
      return;
    }
    if (!_isEditing) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
  }

  /// 处理遥控器确认键，只有确认后才进入编辑态。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (!_isEditing) {
        _startEditing();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  /// 完成编辑后保留焦点但关闭键盘。
  void _finishEditing() {
    if (!_isEditing) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
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
        Focus(
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            focusNode: _focusNode,
            controller: widget.controller,
            obscureText: widget.obscureText,
            readOnly: !_isEditing,
            showCursor: _isEditing,
            textInputAction: TextInputAction.done,
            onTap: _startEditing,
            onEditingComplete: _finishEditing,
            style: FontUtils.poppins(fontSize: 18, color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: FontUtils.poppins(
                fontSize: 16,
                color: const Color(0xFF59656C),
              ),
              filled: true,
              fillColor: const Color(0xFF0E1112),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF293136)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF293136)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.focus, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// TV 设置主题色选项行。
class _TvThemeOptionRow extends StatelessWidget {
  /// 创建 TV 设置主题色选项行。
  const _TvThemeOptionRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// 设置项标签。
  final String label;

  /// 当前主题色标识。
  final String value;

  /// 可选主题色列表。
  final List<TvThemePalette> options;

  /// 主题色变更回调。
  final ValueChanged<String> onChanged;

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
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final selected = option.key == value;
            return TvFocusable(
              directionalRepeatThrottleGroupKey: 'tv-setting-theme-$label',
              focusMemoryGroupKey: 'tv-setting-theme-$label',
              onPressed: () => onChanged(option.key),
              builder: (context, hasFocus) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? option.accent : const Color(0xFF0E1112),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasFocus
                          ? Colors.white
                          : selected
                              ? option.accent
                              : const Color(0xFF293136),
                      width: hasFocus ? 2 : 1,
                    ),
                  ),
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
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? option.selectedText
                              : const Color(0xFFD9E2E0),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// TV 设置选项行。
class _TvOptionRow extends StatelessWidget {
  /// 创建 TV 设置选项行。
  const _TvOptionRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// 设置项标签。
  final String label;

  /// 当前选中值。
  final String value;

  /// 可选值列表。
  final List<String> options;

  /// 选项变更回调。
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
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
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final selected = option == value;
            return TvFocusable(
              directionalRepeatThrottleGroupKey: 'tv-setting-option-$label',
              focusMemoryGroupKey: 'tv-setting-option-$label',
              onPressed: () => onChanged(option),
              builder: (context, hasFocus) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? palette.accent : const Color(0xFF0E1112),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasFocus
                          ? Colors.white
                          : selected
                              ? palette.accent
                              : const Color(0xFF293136),
                      width: hasFocus ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    option,
                    style: FontUtils.poppins(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? palette.selectedText
                          : const Color(0xFFD9E2E0),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// TV 设置操作按钮。
class _TvActionButton extends StatelessWidget {
  /// 创建 TV 设置操作按钮。
  const _TvActionButton({
    required this.label,
    required this.onPressed,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      onPressed: onPressed,
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
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// 设置项文案。
  final String label;

  /// 当前开关值。
  final bool value;

  /// 开关变更回调。
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
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
          Switch(
            value: value,
            activeThumbColor: palette.accent,
            activeTrackColor: palette.accent.withValues(alpha: 0.32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// TV 设置滑杆行。
class _TvSliderRow extends StatelessWidget {
  /// 创建 TV 设置滑杆行。
  const _TvSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  /// 设置项文案。
  final String label;

  /// 当前值。
  final double value;

  /// 最小值。
  final double min;

  /// 最大值。
  final double max;

  /// 当前值文案。
  final String valueLabel;

  /// 值变更回调。
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: palette.accent,
            inactiveColor: palette.disabledFill,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
