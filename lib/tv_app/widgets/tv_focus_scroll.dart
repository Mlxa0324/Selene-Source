import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// TV 焦点滚动辅助。
///
/// 统一处理遥控器焦点进入纵向滚动列表时的自动平滑滚动。
class TvFocusScroll {
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
        axisDirection: scrollable.axisDirection,
      );
      scrollable.position.animateTo(
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
    final itemCenter = leadingOffset + (itemExtent / 2);
    final triggerLine = position.pixels +
        (position.viewportDimension * horizontalTriggerFraction);

    if (itemCenter <= triggerLine) {
      return defaultOffset;
    }

    final earlyScrollOffset =
        (itemCenter - (position.viewportDimension * horizontalTriggerFraction))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    return earlyScrollOffset > defaultOffset
        ? earlyScrollOffset
        : defaultOffset;
  }
}
