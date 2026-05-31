import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selene/tv_app/widgets/tv_design_canvas.dart';

/// TV 主题色调色板。
///
/// 只承载 TV 端焦点、选中态和主按钮颜色，避免影响普通端主题。
class TvThemePalette {
  /// 创建 TV 主题色调色板。
  const TvThemePalette({
    required this.key,
    required this.label,
    required this.accent,
    required this.focus,
    required this.focusFill,
    required this.disabledFill,
    required this.selectedText,
  });

  /// 主题唯一标识。
  final String key;

  /// 设置页展示名称。
  final String label;

  /// 主色，用于选中态和主要按钮。
  final Color accent;

  /// 焦点描边色。
  final Color focus;

  /// 焦点弱背景色。
  final Color focusFill;

  /// 禁用按钮背景色。
  final Color disabledFill;

  /// 主色背景上的文字颜色。
  final Color selectedText;

  /// 默认 Ivy 绿色主题。
  static const String ivyGreenKey = 'ivy_green';

  /// 奈飞红主题标识。
  static const String netflixRedKey = 'netflix_red';

  /// 柔和蓝主题标识。
  static const String softBlueKey = 'soft_blue';

  /// 默认 Ivy 绿色主题。
  static const TvThemePalette ivyGreen = TvThemePalette(
    key: ivyGreenKey,
    label: 'Ivy 绿',
    accent: Color(0xFF26C96F),
    focus: Color(0xFF42D37B),
    focusFill: Color(0xFF1D2A24),
    disabledFill: Color(0xFF33413A),
    selectedText: Colors.black,
  );

  /// 奈飞红主题。
  static const TvThemePalette netflixRed = TvThemePalette(
    key: netflixRedKey,
    label: '奈飞红',
    accent: Color(0xFFE50914),
    focus: Color(0xFFFF3B45),
    focusFill: Color(0xFF2D1719),
    disabledFill: Color(0xFF3F2527),
    selectedText: Colors.white,
  );

  /// 柔和蓝主题。
  static const TvThemePalette softBlue = TvThemePalette(
    key: softBlueKey,
    label: '柔和蓝',
    accent: Color(0xFF5B7CFA),
    focus: Color(0xFF7F99FF),
    focusFill: Color(0xFF222A46),
    disabledFill: Color(0xFF343B50),
    selectedText: Colors.white,
  );

  /// 所有可选 TV 主题色。
  static const List<TvThemePalette> values = [
    netflixRed,
    ivyGreen,
    softBlue,
  ];

  /// 默认 TV 主题色。
  static const TvThemePalette defaultPalette = netflixRed;

  /// 根据存储标识解析主题色。
  static TvThemePalette fromKey(String key) {
    return values.firstWhere(
      (palette) => palette.key == key,
      orElse: () => defaultPalette,
    );
  }
}

/// TV 页面共享中性色。
///
/// 集中管理非主题主色的背景和卡片底色，保证首页、详情页和列表页一致。
class TvThemeColors {
  /// 私有构造，避免实例化工具类。
  const TvThemeColors._();

  /// 右侧内容区和选集、换源等卡片底色。
  static const Color cardSurface = Color(0xFF4B4E5A);

  /// 卡片底色上的弱边框色。
  static const Color cardSurfaceBorder = Color(0xFF616574);
}

/// TV 页面背景配置。
///
/// 独立承载 TV 页面级底色，避免和焦点主色耦合在一起。
class TvThemeBackground {
  /// 创建 TV 页面背景配置。
  const TvThemeBackground({
    required this.key,
    required this.label,
    required this.color,
  });

  /// 背景唯一标识。
  final String key;

  /// 设置页展示名称。
  final String label;

  /// 页面级背景色。
  final Color color;

  /// 深蓝灰背景。
  static const String deepBlueKey = 'deep_blue';

  /// 深黑夜幕背景。
  static const String deepBlackKey = 'deep_black';

  /// 深蓝灰背景。
  static const TvThemeBackground deepBlue = TvThemeBackground(
    key: deepBlueKey,
    label: '深蓝灰',
    color: Color(0xFF1A1D29),
  );

  /// 深黑夜幕背景。
  static const TvThemeBackground deepBlack = TvThemeBackground(
    key: deepBlackKey,
    label: '深黑夜幕',
    color: Color(0xFF0A0D0E),
  );

  /// 当前可选背景色列表。
  static const List<TvThemeBackground> values = [
    deepBlue,
    deepBlack,
  ];

  /// 根据存储标识解析背景色。
  static TvThemeBackground fromKey(String key) {
    return values.firstWhere(
      (background) => background.key == key,
      orElse: () => deepBlue,
    );
  }
}

/// TV 卡片焦点效果模式。
///
/// 用于控制首页横向列表和纵向 Grid 的卡片焦点表现，两个效果互斥。
enum TvFocusEffectMode {
  /// 仅保留当前卡片自身放大和焦点边框。
  magnifier(
    key: 'magnifier',
    label: '放大镜',
  ),

  /// 平滑移动的共享外边框。
  smoothFrame(
    key: 'smooth_frame',
    label: '平滑外框',
  );

  /// 创建 TV 卡片焦点效果模式。
  const TvFocusEffectMode({
    required this.key,
    required this.label,
  });

  /// 存储标识。
  final String key;

  /// 设置页展示名称。
  final String label;

  /// 默认焦点效果。
  static const TvFocusEffectMode defaultMode = magnifier;

  /// 平滑外框模式标识。
  static const String smoothFrameKey = 'smooth_frame';

  /// 放大镜模式标识。
  static const String magnifierKey = 'magnifier';

  /// 根据存储标识解析焦点效果。
  static TvFocusEffectMode fromKey(String key) {
    return values.firstWhere(
      (mode) => mode.key == key,
      orElse: () => defaultMode,
    );
  }
}

/// TV 主题色服务。
///
/// 负责读取、保存并通知 TV 页面刷新主题色。
class TvThemeService extends ChangeNotifier {
  /// 创建 TV 主题色服务。
  TvThemeService();

  /// 本地存储 Key。
  static const String storageKey = 'tv_theme_palette_key';

  /// TV 页面背景色本地存储 Key。
  static const String backgroundStorageKey = 'tv_theme_background_key';

  /// TV 焦点效果本地存储 Key。
  static const String focusEffectStorageKey = 'tv_focus_effect_mode_key';

  /// 当前主题色。
  TvThemePalette _palette = TvThemePalette.defaultPalette;

  /// 当前 TV 页面背景色。
  TvThemeBackground _background = TvThemeBackground.deepBlue;

  /// 当前 TV 卡片焦点效果。
  TvFocusEffectMode _focusEffectMode = TvFocusEffectMode.defaultMode;

  /// 当前主题色。
  TvThemePalette get palette => _palette;

  /// 当前主题标识。
  String get themeKey => _palette.key;

  /// 当前背景配置。
  TvThemeBackground get background => _background;

  /// 当前背景标识。
  String get backgroundKey => _background.key;

  /// 当前 TV 卡片焦点效果。
  TvFocusEffectMode get focusEffectMode => _focusEffectMode;

  /// 当前 TV 卡片焦点效果标识。
  String get focusEffectModeKey => _focusEffectMode.key;

  /// 读取本地主题色配置。
  Future<void> load() async {
    _palette = TvThemePalette.fromKey(await loadSavedThemeKey());
    _background = TvThemeBackground.fromKey(await loadSavedBackgroundKey());
    _focusEffectMode =
        TvFocusEffectMode.fromKey(await loadSavedFocusEffectModeKey());
    notifyListeners();
  }

  /// 切换主题色并持久化。
  Future<void> setThemeKey(String key) async {
    final next = TvThemePalette.fromKey(key);
    if (next.key == _palette.key) {
      return;
    }
    _palette = next;
    notifyListeners();
    await saveThemeKey(next.key);
  }

  /// 切换页面背景色并持久化。
  Future<void> setBackgroundKey(String key) async {
    final next = TvThemeBackground.fromKey(key);
    if (next.key == _background.key) {
      return;
    }
    _background = next;
    notifyListeners();
    await saveBackgroundKey(next.key);
  }

  /// 切换卡片焦点效果并持久化。
  Future<void> setFocusEffectModeKey(String key) async {
    final next = TvFocusEffectMode.fromKey(key);
    if (next.key == _focusEffectMode.key) {
      return;
    }
    _focusEffectMode = next;
    notifyListeners();
    await saveFocusEffectModeKey(next.key);
  }

  /// 读取已保存的主题标识。
  static Future<String> loadSavedThemeKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey) ?? TvThemePalette.defaultPalette.key;
  }

  /// 读取已保存的背景标识。
  static Future<String> loadSavedBackgroundKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(backgroundStorageKey) ??
        TvThemeBackground.deepBlue.key;
  }

  /// 读取已保存的卡片焦点效果标识。
  static Future<String> loadSavedFocusEffectModeKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(focusEffectStorageKey) ??
        TvFocusEffectMode.defaultMode.key;
  }

  /// 保存主题标识。
  static Future<void> saveThemeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, TvThemePalette.fromKey(key).key);
  }

  /// 保存背景标识。
  static Future<void> saveBackgroundKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      backgroundStorageKey,
      TvThemeBackground.fromKey(key).key,
    );
  }

  /// 保存卡片焦点效果标识。
  static Future<void> saveFocusEffectModeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      focusEffectStorageKey,
      TvFocusEffectMode.fromKey(key).key,
    );
  }
}

/// TV 主题色作用域。
///
/// TV 页面通过 [TvTheme.of] 读取当前主题色。
class TvTheme extends InheritedNotifier<TvThemeService> {
  /// 创建 TV 主题色作用域。
  const TvTheme({
    super.key,
    required TvThemeService service,
    required super.child,
  }) : super(notifier: service);

  /// 获取当前 TV 主题色；没有作用域时回退默认奈飞红。
  static TvThemePalette of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<TvTheme>()
            ?.notifier
            ?.palette ??
        TvThemePalette.defaultPalette;
  }

  /// 获取当前 TV 页面背景配置；没有作用域时回退默认深蓝灰。
  static TvThemeBackground backgroundOf(BuildContext context) {
    return maybeServiceOf(context)?.background ?? TvThemeBackground.deepBlue;
  }

  /// 获取当前 TV 卡片焦点效果；没有作用域时回退平滑外框。
  static TvFocusEffectMode focusEffectModeOf(BuildContext context) {
    return maybeServiceOf(context)?.focusEffectMode ??
        TvFocusEffectMode.defaultMode;
  }

  /// 获取当前 TV 主题服务；测试或独立页面可能没有作用域。
  static TvThemeService? maybeServiceOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TvTheme>()?.notifier;
  }

  /// 使用当前作用域中的 TV 主题服务包装新的子树。
  ///
  /// `Navigator.push` 和 `showDialog` 创建的新路由会脱离当前页面的
  /// `TvTheme` 作用域，这里把同一份主题服务继续透传过去，保证独立页
  /// 和弹窗在主题切换后立即刷新。
  static Widget wrapScope({
    required BuildContext context,
    required Widget child,
  }) {
    final service = maybeServiceOf(context);
    final designMetrics = TvDesignCanvas.maybeOf(context);
    final wrappedChild = service == null
        ? child
        : TvTheme(
            service: service,
            child: child,
          );

    if (designMetrics == null) {
      return wrappedChild;
    }

    return TvDesignCanvas(
      preset: designMetrics.preset,
      child: wrappedChild,
    );
  }
}
