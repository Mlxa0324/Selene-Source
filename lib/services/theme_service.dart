import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:macos_window_utils/macos_window_utils.dart';
import '../models/app_theme_scheme.dart';
import 'user_data_service.dart';

class ThemeService extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeScheme _appThemeScheme = kDefaultAppThemeScheme;
  Brightness _lastPlatformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  ThemeMode get themeMode => _themeMode;
  AppThemeScheme get appThemeScheme => _appThemeScheme;
  Color get accentColor => _appThemeScheme.seedColorFor(
        isDarkMode ? Brightness.dark : Brightness.light,
      );

  Color get lightScaffoldBackground => const Color(0xFFFCFEFF);
  Color get darkScaffoldBackground => const Color(0xFF121212);

  Color accentWithAlpha(double alpha, {Brightness? brightness}) {
    final targetBrightness =
        brightness ?? (isDarkMode ? Brightness.dark : Brightness.light);
    return _appThemeScheme
        .seedColorFor(targetBrightness)
        .withValues(alpha: alpha.clamp(0.0, 1.0));
  }

  Color accentTint(double amount, {Brightness? brightness, Color? baseColor}) {
    final targetBrightness =
        brightness ?? (isDarkMode ? Brightness.dark : Brightness.light);
    final resolvedBaseColor = baseColor ??
        (targetBrightness == Brightness.dark
            ? darkScaffoldBackground
            : lightScaffoldBackground);

    return Color.lerp(
      resolvedBaseColor,
      _appThemeScheme.seedColorFor(targetBrightness),
      amount.clamp(0.0, 1.0),
    )!;
  }

  /// 构建播放页选中卡片底色，统一使用白底轻染避免黑底叠色发脏。
  Color selectedCardSurface({Brightness? brightness}) {
    final targetBrightness =
        brightness ?? (isDarkMode ? Brightness.dark : Brightness.light);

    return accentTint(
      targetBrightness == Brightness.dark ? 0.09 : 0.045,
      brightness: targetBrightness,
      baseColor: Colors.white,
    );
  }

  /// 构建播放页选中卡片边框色，保持主题识别度但不过分厚重。
  Color selectedCardBorder({Brightness? brightness}) {
    final targetBrightness =
        brightness ?? (isDarkMode ? Brightness.dark : Brightness.light);

    return accentTint(
      targetBrightness == Brightness.dark ? 0.46 : 0.42,
      brightness: targetBrightness,
      baseColor: Colors.white,
    );
  }

  List<Color> get lightScaffoldGradientColors => [
        accentTint(
          0.045,
          brightness: Brightness.light,
          baseColor: Colors.white,
        ),
        accentTint(
          0.035,
          brightness: Brightness.light,
          baseColor: const Color(0xFFFCFEFF),
        ),
        accentTint(
          0.025,
          brightness: Brightness.light,
          baseColor: Colors.white,
        ),
        accentTint(
          0.035,
          brightness: Brightness.light,
          baseColor: const Color(0xFFF8FCFF),
        ),
      ];

  Color get accentHoverColor => Color.lerp(
        accentColor,
        isDarkMode ? Colors.white : Colors.black,
        isDarkMode ? 0.16 : 0.1,
      )!;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // 当为系统模式时，需要根据当前系统主题判断
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  ThemeService() {
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _refreshSystemThemeIfNeeded(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSystemThemeIfNeeded();
    }
  }

  void _refreshSystemThemeIfNeeded({bool force = false}) {
    final currentBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final brightnessChanged = currentBrightness != _lastPlatformBrightness;
    _lastPlatformBrightness = currentBrightness;

    if (_themeMode != ThemeMode.system) {
      return;
    }

    if (!force && !brightnessChanged) {
      return;
    }

    notifyListeners();
    _updateMacOSWindowAppearance();
  }

  void _loadTheme() async {
    // 每次启动都默认跟随系统主题，不保存用户的手动选择
    _themeMode = ThemeMode.system;
    _appThemeScheme = await UserDataService.getAppThemeScheme();
    _lastPlatformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    notifyListeners();
    _updateMacOSWindowAppearance();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _lastPlatformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // 不再保存到 SharedPreferences，每次启动都重新遵循系统主题
    notifyListeners();
    _updateMacOSWindowAppearance();
  }

  Future<void> setAppThemeScheme(AppThemeScheme scheme) async {
    if (_appThemeScheme == scheme) {
      return;
    }
    _appThemeScheme = scheme;
    await UserDataService.saveAppThemeScheme(scheme);
    notifyListeners();
    _updateMacOSWindowAppearance();
  }

  // 更新 macOS 窗口外观
  void _updateMacOSWindowAppearance() async {
    if (!Platform.isMacOS) return;

    try {
      // 使用 WindowManipulator.overrideMacOSBrightness 来设置窗口外观
      if (isDarkMode) {
        await WindowManipulator.overrideMacOSBrightness(dark: true);
      } else {
        await WindowManipulator.overrideMacOSBrightness(dark: false);
      }
    } catch (e) {
      // 忽略错误，可能在某些环境下不支持
      debugPrint('Failed to update macOS window appearance: $e');
    }
  }

  void toggleTheme(BuildContext context) async {
    switch (_themeMode) {
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.system:
        // 当为系统模式时，检测当前系统主题并切换到相反模式
        final brightness = MediaQuery.of(context).platformBrightness;
        if (brightness == Brightness.light) {
          setThemeMode(ThemeMode.dark);
        } else {
          setThemeMode(ThemeMode.light);
        }
        break;
    }
  }

  ThemeData get lightTheme {
    final seedColor = _appThemeScheme.seedColorFor(Brightness.light);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final titleColor = colorScheme.onSurface;
    final bodyColor = colorScheme.onSurface;
    final subColor = colorScheme.onSurfaceVariant;

    // Windows 下使用微软雅黑以获得更好的中文渲染
    final textTheme = Platform.isWindows
        ? ThemeData.light().textTheme.copyWith(
              bodyLarge: TextStyle(
                color: bodyColor,
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodyMedium: TextStyle(
                color: bodyColor,
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodySmall: TextStyle(
                color: subColor,
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              titleLarge: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              titleMedium: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              titleSmall: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
            )
        : TextTheme(
            bodyLarge: TextStyle(color: bodyColor),
            bodyMedium: TextStyle(color: bodyColor),
            bodySmall: TextStyle(color: subColor),
            titleLarge: TextStyle(color: titleColor),
            titleMedium: TextStyle(color: titleColor),
            titleSmall: TextStyle(color: titleColor),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightScaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: titleColor,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFffffff),
        elevation: 2,
      ),
      textTheme: textTheme,
      fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
    );
  }

  ThemeData get darkTheme {
    final seedColor = _appThemeScheme.seedColorFor(Brightness.dark);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    // Windows 下使用微软雅黑以获得更好的中文渲染
    final textTheme = Platform.isWindows
        ? ThemeData.dark().textTheme.copyWith(
              bodyLarge: const TextStyle(
                color: Color(0xFFffffff),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodyMedium: const TextStyle(
                color: Color(0xFFffffff),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodySmall: const TextStyle(
                color: Color(0xFFb0b0b0),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              titleLarge: const TextStyle(
                color: Color(0xFFffffff),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              titleMedium: const TextStyle(
                color: Color(0xFFffffff),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              titleSmall: const TextStyle(
                color: Color(0xFFffffff),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
            )
        : const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFFffffff)),
            bodyMedium: TextStyle(color: Color(0xFFffffff)),
            bodySmall: TextStyle(color: Color(0xFFb0b0b0)),
            titleLarge: TextStyle(color: Color(0xFFffffff)),
            titleMedium: TextStyle(color: Color(0xFFffffff)),
            titleSmall: TextStyle(color: Color(0xFFffffff)),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkScaffoldBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1e1e1e),
        foregroundColor: Color(0xFFffffff),
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1e1e1e),
        elevation: 2,
      ),
      textTheme: textTheme,
      fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
    );
  }
}
