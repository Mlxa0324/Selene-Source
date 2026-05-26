import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';

/// TV 焦点组件构建函数。
///
/// [hasFocus] 表示当前控件是否获得遥控器焦点。
typedef TvFocusableBuilder = Widget Function(
  BuildContext context,
  bool hasFocus,
);

/// TV 遥控器焦点封装组件。
///
/// 统一处理方向键焦点、确认键点击和焦点高亮状态。
class TvFocusable extends StatefulWidget {
  /// 创建 TV 焦点封装组件。
  ///
  /// [builder] 构建不同焦点态下的内容。
  /// [onPressed] 处理遥控器确认键或鼠标点击。
  /// [onFocusChanged] 处理焦点进入和离开。
  /// [autoScrollOnFocus] 控制获焦后是否自动滚动到可见区域。
  const TvFocusable({
    super.key,
    required this.builder,
    this.focusNode,
    this.onPressed,
    this.onFocusChanged,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.autofocus = false,
    this.autoScrollOnFocus = true,
    this.focusScrollAlignment = TvFocusScroll.defaultAlignment,
    this.directionalRepeatThrottleGroupKey,
    this.directionalRepeatThrottleDuration = const Duration(milliseconds: 120),
  });

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 焦点态内容构建器。
  final TvFocusableBuilder builder;

  /// 确认键点击回调。
  final VoidCallback? onPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 是否默认请求焦点。
  final bool autofocus;

  /// 获得焦点时是否自动平滑滚动到视口内。
  final bool autoScrollOnFocus;

  /// 获焦自动滚动时的目标对齐位置。
  final double focusScrollAlignment;

  /// 方向键长按节流分组 Key。
  ///
  /// 纯文字列表长按时，重复方向事件会比焦点动画快很多。
  /// 同一个分组内会共享节流状态，避免焦点跳过中间选中态。
  final Object? directionalRepeatThrottleGroupKey;

  /// 方向键长按节流时长。
  ///
  /// 仅在 [directionalRepeatThrottleGroupKey] 不为空时生效。
  final Duration directionalRepeatThrottleDuration;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  /// 方向键长按节流状态表。
  ///
  /// 文字列表的焦点会在多个子项之间切换，因此需要跨子项共享最近一次方向事件。
  static final Map<Object, _TvDirectionalRepeatState> _directionalRepeatStates =
      <Object, _TvDirectionalRepeatState>{};

  /// 内部焦点节点。
  ///
  /// 未传入外部节点时使用，便于测试和焦点定位读取当前 Focus 节点。
  final FocusNode _ownedFocusNode = FocusNode();

  /// 自动滚动目标 Key。
  ///
  /// 使用真实渲染节点的上下文，避免 StatefulWidget 上下文无法定位尺寸。
  final GlobalKey _scrollTargetKey = GlobalKey();

  /// 当前控件是否获得焦点。
  bool _hasFocus = false;

  /// 当前实际使用的焦点节点。
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _ownedFocusNode;

  @override
  void dispose() {
    _ownedFocusNode.dispose();
    super.dispose();
  }

  /// 处理遥控器确认键和边界方向键。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onPressed?.call();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        widget.onArrowLeft != null) {
      widget.onArrowLeft?.call();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        widget.onArrowRight != null) {
      widget.onArrowRight?.call();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        widget.onArrowUp != null) {
      widget.onArrowUp?.call();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.onArrowDown != null) {
      widget.onArrowDown?.call();
      return KeyEventResult.handled;
    }

    final directionalRepeatResult = _handleDirectionalRepeatThrottle(event);
    if (directionalRepeatResult != null) {
      return directionalRepeatResult;
    }

    return KeyEventResult.ignored;
  }

  /// 处理文字列表的方向键长按节流。
  ///
  /// 首次方向键仍交给默认焦点系统处理，只有过密的重复事件才会被吞掉。
  KeyEventResult? _handleDirectionalRepeatThrottle(KeyEvent event) {
    final groupKey = widget.directionalRepeatThrottleGroupKey;
    if (groupKey == null) {
      return null;
    }

    final logicalKey = event.logicalKey;
    if (!_isDirectionalKey(logicalKey)) {
      return null;
    }

    final currentTime = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final previousState = _directionalRepeatStates[groupKey];
    final isRepeatWithinCooldown = event is KeyRepeatEvent &&
        previousState != null &&
        previousState.logicalKey == logicalKey &&
        currentTime - previousState.timeStamp <
            widget.directionalRepeatThrottleDuration;

    if (isRepeatWithinCooldown) {
      return KeyEventResult.handled;
    }

    _directionalRepeatStates[groupKey] = _TvDirectionalRepeatState(
      logicalKey: logicalKey,
      timeStamp: currentTime,
    );
    return null;
  }

  /// 判断是否属于方向键。
  bool _isDirectionalKey(LogicalKeyboardKey logicalKey) {
    return logicalKey == LogicalKeyboardKey.arrowLeft ||
        logicalKey == LogicalKeyboardKey.arrowRight ||
        logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.arrowDown;
  }

  /// 同步真实焦点态。
  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _hasFocus = hasFocus;
    });
    if (hasFocus && widget.autoScrollOnFocus) {
      final targetContext = _scrollTargetKey.currentContext;
      if (targetContext != null) {
        TvFocusScroll.ensureVisible(
          targetContext,
          alignment: widget.focusScrollAlignment,
        );
      }
    }
    widget.onFocusChanged?.call(hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: _handleFocusChange,
      child: GestureDetector(
        key: _scrollTargetKey,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: widget.builder(context, _hasFocus),
      ),
    );
  }
}

/// 方向键长按节流状态。
class _TvDirectionalRepeatState {
  /// 创建方向键长按节流状态。
  const _TvDirectionalRepeatState({
    required this.logicalKey,
    required this.timeStamp,
  });

  /// 最近一次方向键。
  final LogicalKeyboardKey logicalKey;

  /// 最近一次方向事件时间。
  final Duration timeStamp;
}
