import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// TV 焦点滚动辅助。
///
/// 统一处理遥控器焦点进入纵向滚动列表时的自动平滑滚动。
class TvFocusScroll {
  /// 目标滚动位置抖动容差。
  ///
  /// 焦点切换时同一控件可能连续触发多次 ensureVisible，位置差异极小时
  /// 没必要再发一轮动画，否则会在 TV 长列表里制造额外掉帧。
  static const double offsetEpsilon = 1.0;

  /// 小位移直接跳转阈值。
  ///
  /// 低配 TV 上很短距离也开一段滚动动画，方向键快速移动时会叠出多余帧。
  static const double immediateOffsetThreshold = 8.0;

  /// 同一滚动位置重复请求合并窗口。
  static const Duration duplicateRequestWindow = Duration(milliseconds: 90);

  /// 最近一次滚动请求缓存。
  ///
  /// 焦点切换、尺寸测量和 post-frame 回调可能在短时间内给同一个列表发出
  /// 相同目标，这里只保留第一轮动画，避免重复 `animateTo` 抢帧。
  static final Map<ScrollPosition, _TvFocusScrollRequest> _recentRequests =
      <ScrollPosition, _TvFocusScrollRequest>{};

  /// 焦点进入横向列表后，超过视口这个比例时开始提前滚动。
  ///
  /// 该值略小于屏幕中心，确保用户浏览到第 5 个左右就开始平滑推进，
  /// 不需要等到最后一项才触发滚动。
  static const double horizontalTriggerFraction = 0.42;

  /// 焦点控件滚动到视口内时的默认对齐位置。
  ///
  /// 该值略偏上，方便用户看到当前焦点下方还有更多内容。
  static const double defaultAlignment = 0.24;

  /// 首页横向区块获得焦点时的对齐位置。
  ///
  /// 区块级滚动需要更靠近顶部，形成更明显的整行上移效果。
  static const double sectionAlignment = 0.04;

  /// 焦点滚动动画时长。
  static const Duration duration = Duration(milliseconds: 380);

  /// 焦点滚动动画曲线。
  static const Curve curve = Curves.easeOutCubic;

  /// 将指定 [context] 对应控件平滑滚动到可见区域。
  static void ensureVisible(
    BuildContext context, {
    double alignment = defaultAlignment,
    double horizontalTriggerFraction = TvFocusScroll.horizontalTriggerFraction,
  }) {
    // 等本轮焦点和布局稳定后再滚动，避免方向键切换时读到旧位置。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      final scrollable = Scrollable.maybeOf(context);
      final renderObject = context.findRenderObject();
      if (scrollable == null || renderObject == null) {
        return;
      }
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) {
        return;
      }
      final position = scrollable.position;
      final targetOffset = _resolveTargetOffset(
        viewport: viewport,
        renderObject: renderObject,
        position: position,
        alignment: alignment,
        horizontalTriggerFraction: horizontalTriggerFraction,
        axisDirection: scrollable.axisDirection,
      );
      if ((position.pixels - targetOffset).abs() <= offsetEpsilon) {
        return;
      }
      if (_isDuplicateRequest(position, targetOffset)) {
        return;
      }
      _rememberRequest(position, targetOffset);
      final delta = (position.pixels - targetOffset).abs();
      if (delta <= immediateOffsetThreshold) {
        position.jumpTo(targetOffset);
        return;
      }
      position.animateTo(
        targetOffset,
        duration: duration,
        curve: curve,
      );
    });
  }

  /// 计算焦点滚动目标位置。
  ///
  /// 横向列表在焦点越过视口稳定浏览线后提前推进，纵向列表继续沿用
  /// `RenderAbstractViewport.getOffsetToReveal` 的标准对齐能力。
  static double _resolveTargetOffset({
    required RenderAbstractViewport viewport,
    required RenderObject renderObject,
    required ScrollPosition position,
    required double alignment,
    required double horizontalTriggerFraction,
    required AxisDirection axisDirection,
  }) {
    final defaultOffset = viewport
        .getOffsetToReveal(renderObject, alignment)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    final isHorizontal = axisDirection == AxisDirection.left ||
        axisDirection == AxisDirection.right;
    if (!isHorizontal) {
      return defaultOffset;
    }

    final leadingOffset =
        viewport.getOffsetToReveal(renderObject, 0).offset.toDouble();
    final trailingOffset =
        viewport.getOffsetToReveal(renderObject, 1).offset.toDouble();
    final itemExtent =
        position.viewportDimension - (leadingOffset - trailingOffset).abs();
    final viewportStart = position.pixels;
    final viewportEnd = viewportStart + position.viewportDimension;
    final itemStart = leadingOffset;
    final itemEnd = itemStart + itemExtent;
    final itemCenter = leadingOffset + (itemExtent / 2);
    final triggerFraction = horizontalTriggerFraction.clamp(0.0, 1.0);
    final triggerLine =
        viewportStart + (position.viewportDimension * triggerFraction);

    if (itemStart < viewportStart) {
      return itemStart
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
    }

    if (itemEnd > viewportEnd) {
      final revealEndOffset = itemEnd - position.viewportDimension;
      final triggerOffset =
          itemCenter - (position.viewportDimension * triggerFraction);
      final targetOffset =
          triggerOffset > revealEndOffset ? triggerOffset : revealEndOffset;
      return targetOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
    }

    if (itemCenter <= triggerLine) {
      return viewportStart
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
    }

    final earlyScrollOffset =
        (itemCenter - (position.viewportDimension * triggerFraction))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    return earlyScrollOffset;
  }

  /// 判断本次滚动是否是短时间内的重复目标。
  static bool _isDuplicateRequest(
    ScrollPosition position,
    double targetOffset,
  ) {
    final request = _recentRequests[position];
    if (request == null) {
      return false;
    }
    final sameTarget =
        (request.targetOffset - targetOffset).abs() <= offsetEpsilon;
    final stillFresh =
        DateTime.now().difference(request.createdAt) <= duplicateRequestWindow;
    return sameTarget && stillFresh;
  }

  /// 记录本次滚动目标，供短时间重复请求去重。
  static void _rememberRequest(
    ScrollPosition position,
    double targetOffset,
  ) {
    _recentRequests[position] = _TvFocusScrollRequest(
      targetOffset: targetOffset,
      createdAt: DateTime.now(),
    );
  }
}

/// TV 焦点滚动请求记录。
class _TvFocusScrollRequest {
  /// 创建一条滚动请求记录。
  const _TvFocusScrollRequest({
    required this.targetOffset,
    required this.createdAt,
  });

  /// 本次滚动目标位置。
  final double targetOffset;

  /// 本次滚动请求创建时间。
  final DateTime createdAt;
}
