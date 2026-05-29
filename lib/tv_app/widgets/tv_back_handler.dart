import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV 返回键识别工具。
///
/// 统一识别遥控器返回键和模拟器 `Esc`，避免各页面重复维护键值判断。
class TvBackIntent {
  /// 私有构造，避免工具类被实例化。
  const TvBackIntent._();

  /// 当前仍处于按下态的返回键集合。
  ///
  /// 顶层独立页返回首页时，旧页面的 `TvBackHandler` 会立刻销毁，
  /// 但同一次物理按压后续仍可能继续派发到首页。这里改成跨页面共享的
  /// “按下态”锁，确保同一次返回只会触发一次真正的返回动作。
  static final Set<LogicalKeyboardKey> _pressedBackKeys =
      <LogicalKeyboardKey>{};

  /// 返回键按下态的兜底释放定时器。
  ///
  /// 正常路径会由 `KeyUpEvent` 释放；如果某些设备偶发丢失 `KeyUp`，
  /// 这里再用短超时兜底，避免后续返回键永久失效。
  static final Map<LogicalKeyboardKey, Timer> _pressedBackKeyTimers =
      <LogicalKeyboardKey, Timer>{};

  /// 返回键按下态兜底释放时长。
  static const Duration _pressedBackKeyFallbackReleaseDuration =
      Duration(milliseconds: 700);

  /// 判断是否为 TV 端返回类按键。
  static bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;
  }

  /// 记录首次返回键按下。
  ///
  /// 返回 `true` 表示这是当前物理按压的首次 `KeyDown`，可以真正执行返回；
  /// 返回 `false` 表示仍属于同一次按压，当前事件只消费不重复返回。
  static bool registerBackKeyDown(LogicalKeyboardKey key) {
    if (!isBackKey(key)) {
      return false;
    }
    final isFirstDown = _pressedBackKeys.add(key);
    _refreshBackKeyFallbackRelease(key);
    return isFirstDown;
  }

  /// 延续当前返回键按下态。
  ///
  /// 用于吃掉长按重复事件，或兼容个别设备在同一次长按里补发的异常回调。
  static void keepBackKeyPressed(LogicalKeyboardKey key) {
    if (!isBackKey(key) || !_pressedBackKeys.contains(key)) {
      return;
    }
    _refreshBackKeyFallbackRelease(key);
  }

  /// 释放返回键按下态。
  static void releaseBackKey(LogicalKeyboardKey key) {
    if (!isBackKey(key)) {
      return;
    }
    _pressedBackKeys.remove(key);
    _pressedBackKeyTimers.remove(key)?.cancel();
  }

  /// 重置返回键按下态调试数据。
  @visibleForTesting
  static void debugResetBackKeyTracking() {
    for (final timer in _pressedBackKeyTimers.values) {
      timer.cancel();
    }
    _pressedBackKeyTimers.clear();
    _pressedBackKeys.clear();
  }

  /// 刷新返回键按下态的兜底释放计时。
  static void _refreshBackKeyFallbackRelease(LogicalKeyboardKey key) {
    _pressedBackKeyTimers.remove(key)?.cancel();
    _pressedBackKeyTimers[key] = Timer(
      _pressedBackKeyFallbackReleaseDuration,
      () => releaseBackKey(key),
    );
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
    if (!TvBackIntent.isBackKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      TvBackIntent.releaseBackKey(event.logicalKey);
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      TvBackIntent.keepBackKeyPressed(event.logicalKey);
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // 返回键只响应当前物理按压的首次 KeyDown，后续重复事件统一吞掉，
    // 避免子页刚返回时，同一次按压又被首页重新消费一次。
    final isFirstBackKeyDown =
        TvBackIntent.registerBackKeyDown(event.logicalKey);
    if (!isFirstBackKeyDown) {
      return KeyEventResult.handled;
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
