import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV 返回键识别工具。
///
/// 统一识别遥控器返回键和模拟器 `Esc`，避免各页面重复维护键值判断。
class TvBackIntent {
  /// 私有构造，避免工具类被实例化。
  const TvBackIntent._();

  /// 判断是否为 TV 端返回类按键。
  static bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;
  }
}

/// TV 页面返回键包装。
///
/// 为独立路由页面补充模拟器 `Esc` 返回语义，同时把具体返回行为交给
/// 当前页面自己的 `PopScope` / `Navigator` 决定。
class TvBackHandler extends StatefulWidget {
  /// 创建 TV 页面返回键包装。
  const TvBackHandler({
    super.key,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.onBackPressed,
  });

  /// 子树内容。
  final Widget child;

  /// 外部注入的焦点节点。
  final FocusNode? focusNode;

  /// 是否默认请求焦点。
  final bool autofocus;

  /// 返回键回调。
  ///
  /// 返回 `true` 表示事件已处理，不再继续执行默认 `maybePop`；
  /// 返回 `false` 或 `null` 时，会回退到当前路由的默认返回逻辑。
  final Future<bool> Function()? onBackPressed;

  @override
  State<TvBackHandler> createState() => _TvBackHandlerState();
}

class _TvBackHandlerState extends State<TvBackHandler> {
  /// 内部焦点节点。
  final FocusNode _ownedFocusNode = FocusNode(debugLabel: 'tv-back-handler');

  /// 是否已有待执行的返回分发任务。
  ///
  /// 避免长按 `Esc` 或遥控器返回键时，同一页面在一次返回完成前重复触发多次 pop。
  bool _backDispatchScheduled = false;

  /// 当前实际使用的焦点节点。
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _ownedFocusNode;

  @override
  void dispose() {
    _ownedFocusNode.dispose();
    super.dispose();
  }

  /// 处理返回类按键。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 返回键只响应首次按下，长按重复事件统一忽略，
    // 避免子页刚返回时，同一次物理按压的 repeat 又落到上一页。
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (!TvBackIntent.isBackKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    _dispatchBack();
    return KeyEventResult.handled;
  }

  /// 分发返回动作。
  ///
  /// 先给页面自己的拦截机会，例如先关弹层；如果页面未消费，再走路由返回。
  void _dispatchBack() {
    if (_backDispatchScheduled) {
      return;
    }
    _backDispatchScheduled = true;

    Future<void>.microtask(() async {
      try {
        if (!mounted) {
          return;
        }

        final handled = await widget.onBackPressed?.call() ?? false;
        if (handled || !mounted) {
          return;
        }

        await Navigator.of(context).maybePop();
      } finally {
        // 返回链路彻底结束后再放开防重入锁，避免一次长按在同页内触发多次返回。
        _backDispatchScheduled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
