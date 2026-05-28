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

  /// 所有可选 TV 主题色。
  static const List<TvThemePalette> values = [
    ivyGreen,
    netflixRed,
  ];

  /// 根据存储标识解析主题色。
  static TvThemePalette fromKey(String key) {
    return values.firstWhere(
      (palette) => palette.key == key,
      orElse: () => ivyGreen,
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

  /// 当前主题色。
  TvThemePalette _palette = TvThemePalette.ivyGreen;

  /// 当前主题色。
  TvThemePalette get palette => _palette;

  /// 当前主题标识。
  String get themeKey => _palette.key;

  /// 读取本地主题色配置。
  Future<void> load() async {
    _palette = TvThemePalette.fromKey(await loadSavedThemeKey());
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

  /// 读取已保存的主题标识。
  static Future<String> loadSavedThemeKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey) ?? TvThemePalette.ivyGreen.key;
  }

  /// 保存主题标识。
  static Future<void> saveThemeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, TvThemePalette.fromKey(key).key);
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

  /// 获取当前 TV 主题色；没有作用域时回退默认绿。
  static TvThemePalette of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<TvTheme>()
            ?.notifier
            ?.palette ??
        TvThemePalette.ivyGreen;
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
