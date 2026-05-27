import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全局返回键包装。
///
/// 将桌面键盘 `Esc` 和浏览器返回类按键统一映射为 Flutter 路由返回，
/// 让模拟器、桌面调试和 TV 遥控器返回逻辑保持一致。
class GlobalBackHandler extends StatelessWidget {
  /// 创建全局返回键包装。
  const GlobalBackHandler({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  /// 子树内容。
  final Widget child;

  /// 根导航器 Key，用于在 `MaterialApp.builder` 中执行全局返回。
  final GlobalKey<NavigatorState>? navigatorKey;

  /// 判断是否为全局返回类按键。
  static bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;
  }

  /// 处理全局返回快捷键。
  KeyEventResult _handleBackKey() {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) {
      return KeyEventResult.ignored;
    }

    // 放到微任务里立即分发返回，减少静态页面等待下一帧导致的返回迟滞。
    Future<void>.microtask(() {
      navigator.maybePop();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _handleBackKey();
        },
        const SingleActivator(LogicalKeyboardKey.goBack): () {
          _handleBackKey();
        },
        const SingleActivator(LogicalKeyboardKey.browserBack): () {
          _handleBackKey();
        },
      },
      child: child,
    );
  }
}
