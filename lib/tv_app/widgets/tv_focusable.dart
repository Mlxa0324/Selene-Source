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
    this.horizontalFocusScrollTriggerFraction =
        TvFocusScroll.horizontalTriggerFraction,
    this.focusMemoryGroupKey,
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

  /// 横向列表获焦后开始提前滚动的视口比例。
  final double horizontalFocusScrollTriggerFraction;

  /// 上下跨列表焦点记忆分组 Key。
  ///
  /// 同一个列表内的控件使用相同 Key。上下方向离开当前列表时，会优先回到目标列表
  /// 最近一次获焦的控件，避免默认焦点系统每次按几何距离跳到列表开头或就近项。
  final Object? focusMemoryGroupKey;

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

  /// 清理指定分组最近一次记住的焦点项。
  ///
  /// 某些横向列表在离开后需要下次从头进入，此时只清掉“最近一次焦点”即可，
  /// 不影响列表内部节点继续保留同一个焦点记忆分组。
  static void clearLastFocusedForGroup(Object groupKey) {
    _TvFocusableState._lastFocusedByGroup.remove(groupKey);
  }

  /// 将指定分组的入口焦点重置到首个可聚焦项。
  ///
  /// 适用于首页横向分区这类“离开后下次从第一个重新进入”的场景。
  /// 若当前分组里没有可用节点，则回退为清理最近一次焦点记录。
  static void resetGroupEntryToFirstFocusable(Object groupKey) {
    final firstEntry = _TvFocusableState.firstFocusableEntryForGroup(groupKey);
    if (firstEntry == null) {
      _TvFocusableState._lastFocusedByGroup.remove(groupKey);
      return;
    }
    _TvFocusableState._lastFocusedByGroup[groupKey] = firstEntry;
  }

  /// 判断指定分组当前是否仍有子项持有焦点。
  ///
  /// 用于列表在“最后一个焦点离开分组”时执行离组复位。
  static bool groupHasFocusedChild(Object groupKey) {
    final entries = _TvFocusableState._focusMemoryGroups[groupKey];
    if (entries == null || entries.isEmpty) {
      return false;
    }
    for (final entry in entries) {
      if (entry._effectiveFocusNode.hasFocus ||
          entry._effectiveFocusNode.hasPrimaryFocus) {
        return true;
      }
    }
    return false;
  }
}

class _TvFocusableState extends State<TvFocusable> {
  /// 方向键长按节流状态表。
  ///
  /// 文字列表的焦点会在多个子项之间切换，因此需要跨子项共享最近一次方向事件。
  static final Map<Object, _TvDirectionalRepeatState> _directionalRepeatStates =
      <Object, _TvDirectionalRepeatState>{};

  /// 上下焦点判定容差，过滤同一横向列表内的轻微布局偏差。
  static const double _verticalDirectionTolerance = 28;

  /// TV 焦点记忆分组表。
  static final Map<Object, Set<_TvFocusableState>> _focusMemoryGroups =
      <Object, Set<_TvFocusableState>>{};

  /// TV 焦点记忆最后获焦项。
  static final Map<Object, _TvFocusableState> _lastFocusedByGroup =
      <Object, _TvFocusableState>{};

  /// 获取分组内第一个可聚焦的节点。
  ///
  /// 排序规则按大屏上的阅读顺序处理：先上后下，同一行再从左到右。
  static _TvFocusableState? firstFocusableEntryForGroup(Object groupKey) {
    final entries = _focusMemoryGroups[groupKey];
    if (entries == null || entries.isEmpty) {
      return null;
    }

    _TvFocusableState? bestEntry;
    Rect? bestRect;
    for (final entry in entries) {
      if (!entry._isFocusMemoryUsable) {
        continue;
      }
      final rect = entry._globalRect;
      if (rect == null) {
        continue;
      }
      final isBetterEntry = bestRect == null ||
          rect.top < bestRect.top - 1 ||
          ((rect.top - bestRect.top).abs() <= 1 && rect.left < bestRect.left);
      if (isBetterEntry) {
        bestEntry = entry;
        bestRect = rect;
      }
    }
    return bestEntry;
  }

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

  /// 当前已注册的焦点记忆分组。
  Object? _registeredFocusMemoryGroupKey;

  /// 当前实际使用的焦点节点。
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _ownedFocusNode;

  @override
  void initState() {
    super.initState();
    _syncFocusMemoryRegistration();
  }

  @override
  void didUpdateWidget(covariant TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusMemoryRegistration();
  }

  @override
  void dispose() {
    _unregisterFocusMemory();
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

    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final memoryResult = _handleFocusMemoryVerticalNavigation(
        event.logicalKey,
      );
      if (memoryResult != null) {
        return memoryResult;
      }
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

  /// 同步焦点记忆分组注册状态。
  void _syncFocusMemoryRegistration() {
    final nextGroupKey = widget.focusMemoryGroupKey;
    if (_registeredFocusMemoryGroupKey == nextGroupKey) {
      return;
    }
    _unregisterFocusMemory();
    if (nextGroupKey == null) {
      return;
    }
    _focusMemoryGroups
        .putIfAbsent(nextGroupKey, () => <_TvFocusableState>{})
        .add(this);
    _registeredFocusMemoryGroupKey = nextGroupKey;
  }

  /// 取消当前焦点记忆分组注册。
  void _unregisterFocusMemory() {
    final groupKey = _registeredFocusMemoryGroupKey;
    if (groupKey == null) {
      return;
    }
    final group = _focusMemoryGroups[groupKey];
    group?.remove(this);
    if (group?.isEmpty == true) {
      _focusMemoryGroups.remove(groupKey);
    }
    if (_lastFocusedByGroup[groupKey] == this) {
      _lastFocusedByGroup.remove(groupKey);
    }
    _registeredFocusMemoryGroupKey = null;
  }

  /// 处理上下方向跨列表时的焦点记忆跳转。
  KeyEventResult? _handleFocusMemoryVerticalNavigation(LogicalKeyboardKey key) {
    final currentGroupKey = _registeredFocusMemoryGroupKey;
    if (currentGroupKey == null) {
      return null;
    }
    final currentRect = _globalRect;
    if (currentRect == null) {
      return null;
    }
    final direction = key == LogicalKeyboardKey.arrowDown ? 1 : -1;

    // 当前列表在该方向还有可聚焦项时，交给 Flutter 默认焦点系统继续列表内移动。
    final sameGroupTarget = _nearestEntryInDirection(
      entries: _focusMemoryGroups[currentGroupKey] ?? const {},
      currentRect: currentRect,
      direction: direction,
      excludeCurrentGroup: false,
    );
    if (sameGroupTarget != null) {
      return null;
    }

    final target = _nearestRememberedGroupEntry(
      currentGroupKey: currentGroupKey,
      currentRect: currentRect,
      direction: direction,
    );
    if (target == null) {
      return null;
    }

    target._effectiveFocusNode.requestFocus();
    return KeyEventResult.handled;
  }

  /// 查找目标方向上最近的其它列表焦点。
  _TvFocusableState? _nearestRememberedGroupEntry({
    required Object currentGroupKey,
    required Rect currentRect,
    required int direction,
  }) {
    final rememberedEntries = <_TvFocusableState>[];
    for (final entry in _lastFocusedByGroup.entries) {
      if (entry.key == currentGroupKey) {
        continue;
      }
      rememberedEntries.add(entry.value);
    }

    final rememberedTarget = _nearestEntryInDirection(
      entries: rememberedEntries,
      currentRect: currentRect,
      direction: direction,
      excludeCurrentGroup: true,
    );
    if (rememberedTarget != null) {
      return rememberedTarget;
    }

    final fallbackEntries = <_TvFocusableState>[];
    for (final entry in _focusMemoryGroups.entries) {
      if (entry.key == currentGroupKey) {
        continue;
      }
      fallbackEntries.addAll(entry.value);
    }

    return _nearestEntryInDirection(
      entries: fallbackEntries,
      currentRect: currentRect,
      direction: direction,
      excludeCurrentGroup: true,
    );
  }

  /// 查找指定方向上最近的可用焦点项。
  _TvFocusableState? _nearestEntryInDirection({
    required Iterable<_TvFocusableState> entries,
    required Rect currentRect,
    required int direction,
    required bool excludeCurrentGroup,
  }) {
    _TvFocusableState? bestEntry;
    double? bestScore;
    final currentCenter = currentRect.center;
    for (final entry in entries) {
      if (entry == this || !entry._isFocusMemoryUsable) {
        continue;
      }
      if (excludeCurrentGroup &&
          entry._registeredFocusMemoryGroupKey ==
              _registeredFocusMemoryGroupKey) {
        continue;
      }
      final rect = entry._globalRect;
      if (rect == null) {
        continue;
      }
      final deltaY = rect.center.dy - currentCenter.dy;
      final isInDirection = direction > 0
          ? deltaY > _verticalDirectionTolerance
          : deltaY < -_verticalDirectionTolerance;
      if (!isInDirection) {
        continue;
      }
      final deltaX = (rect.center.dx - currentCenter.dx).abs();
      final score = deltaY.abs() * 1000 + deltaX;
      if (bestScore == null || score < bestScore) {
        bestScore = score;
        bestEntry = entry;
      }
    }
    return bestEntry;
  }

  /// 当前项是否可作为焦点记忆目标。
  bool get _isFocusMemoryUsable {
    if (!mounted || !_effectiveFocusNode.canRequestFocus) {
      return false;
    }
    return _globalRect != null;
  }

  /// 获取当前控件全局位置。
  Rect? get _globalRect {
    final targetContext = _scrollTargetKey.currentContext;
    if (targetContext == null) {
      return null;
    }
    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & size;
  }

  /// 同步真实焦点态。
  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _hasFocus = hasFocus;
    });
    if (hasFocus) {
      final groupKey = _registeredFocusMemoryGroupKey;
      if (groupKey != null) {
        _lastFocusedByGroup[groupKey] = this;
      }
    }
    if (hasFocus && widget.autoScrollOnFocus) {
      final targetContext = _scrollTargetKey.currentContext;
      if (targetContext != null) {
        TvFocusScroll.ensureVisible(
          targetContext,
          alignment: widget.focusScrollAlignment,
          horizontalTriggerFraction:
              widget.horizontalFocusScrollTriggerFraction,
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
