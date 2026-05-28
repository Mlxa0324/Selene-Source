import 'dart:math' as math;

import 'package:flutter/material.dart';

/// TV 设计画布指标。
///
/// 统一暴露当前 TV 页面相对于 2K 设计稿的缩放结果。
class TvDesignMetrics {
  /// 创建设计画布指标。
  const TvDesignMetrics({
    required this.scale,
    required this.designSize,
    required this.viewportSize,
  });

  /// 当前视口相对于设计稿的缩放比例。
  final double scale;

  /// 设计稿逻辑尺寸。
  final Size designSize;

  /// 当前实际视口尺寸。
  final Size viewportSize;
}

/// TV 端 2K 设计画布。
///
/// 以 1920x1080 作为设计基准，在较小分辨率下整体等比缩小，保持 TV
/// 页面在 720p 等设备上的视觉比例与 2K 设计稿一致。
class TvDesignCanvas extends StatelessWidget {
  /// 创建设计画布包装。
  const TvDesignCanvas({
    super.key,
    required this.child,
  });

  // /// 设计稿宽度。
  // static const double designWidth = 2560;
  //
  // /// 设计稿高度。
  // static const double designHeight = 1440;
  //
  // /// 设计稿宽度。
  // static const double designWidth = 1920;
  //
  // /// 设计稿高度。
  // static const double designHeight = 1080;

  /// 设计稿宽度。
  static const double designWidth = 1280;

  /// 设计稿高度。
  static const double designHeight = 720;

  /// 子树内容。
  final Widget child;

  /// 读取当前设计画布指标。
  static TvDesignMetrics of(BuildContext context) {
    return maybeOf(context) ??
        TvDesignMetrics(
          scale: 1,
          designSize: const Size(designWidth, designHeight),
          viewportSize: MediaQuery.sizeOf(context),
        );
  }

  /// 尝试读取当前设计画布指标。
  static TvDesignMetrics? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_TvDesignCanvasScope>();
    return scope?.metrics;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : designWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight : designHeight,
        );
        final widthScale = viewportSize.width / designWidth;
        final heightScale = viewportSize.height / designHeight;
        final scale =
            math.min(1.0, math.min(widthScale, heightScale)).toDouble();
        final metrics = TvDesignMetrics(
          scale: scale,
          designSize: const Size(designWidth, designHeight),
          viewportSize: viewportSize,
        );

        return ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: SizedBox(
              width: designWidth * scale,
              height: designHeight * scale,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: designWidth,
                  maxWidth: designWidth,
                  minHeight: designHeight,
                  maxHeight: designHeight,
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: scale,
                    child: SizedBox(
                      width: designWidth,
                      height: designHeight,
                      child: _TvDesignCanvasScope(
                        metrics: metrics,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: const Size(designWidth, designHeight),
                            textScaler: const TextScaler.linear(1),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// TV 设计画布作用域。
///
/// 为 TV 页面子树透传当前缩放指标。
class _TvDesignCanvasScope extends InheritedWidget {
  /// 创建设计画布作用域。
  const _TvDesignCanvasScope({
    required this.metrics,
    required super.child,
  });

  /// 当前设计画布指标。
  final TvDesignMetrics metrics;

  @override
  bool updateShouldNotify(_TvDesignCanvasScope oldWidget) {
    return oldWidget.metrics != metrics;
  }
}
