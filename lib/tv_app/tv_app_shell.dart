import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/screens/tv_home_screen.dart';

/// TV 端应用根壳。
///
/// Android TV 启动后进入该入口，后续 TV 专属页面都挂载在这里。
class TvAppShell extends StatefulWidget {
  /// 创建 TV 端应用根壳。
  const TvAppShell({super.key});

  @override
  State<TvAppShell> createState() => _TvAppShellState();
}

class _TvAppShellState extends State<TvAppShell> {
  /// TV 主题色服务。
  final TvThemeService _themeService = TvThemeService();

  /// TV 根焦点节点。
  ///
  /// 用于统一接住模拟器键盘返回事件，例如 `Esc`。
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'tv-app-shell-root');

  @override
  void initState() {
    super.initState();
    _themeService.load();
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _themeService.dispose();
    super.dispose();
  }

  /// 判断是否为 TV 端返回类按键。
  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;
  }

  /// 统一处理 TV 根壳上的返回键。
  ///
  /// 模拟器里按 `Esc` 也按 TV 返回键语义处理，具体返回行为交给当前页面
  /// 的 `PopScope` / `Navigator` 自己决定，例如先关筛选面板、先关菜单等。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (!_isBackKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).maybePop();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: TvTheme(
        service: _themeService,
        child: const TvHomeScreen(),
      ),
    );
  }
}
