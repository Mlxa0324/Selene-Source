import 'dart:math' as math;

import 'package:flutter/material.dart';

/// TV 设计稿预设。
///
/// 统一管理自动模式与常用固定设计稿尺寸，避免通过注释来回切换常量。
enum TvDesignPreset {
  /// 自动根据当前视口选择最合适的设计稿。
  auto(
    label: '自动',
    designSize: null,
  ),

  /// 720p 设计稿。
  hd720(
    label: '720p',
    designSize: Size(1280, 720),
  ),

  /// 1080p 设计稿。
  fullHd1080(
    label: '1080p',
    designSize: Size(1920, 1080),
  ),

  /// 1440p 设计稿。
  qhd1440(
    label: '1440p',
    designSize: Size(2560, 1440),
  );

  /// 创建设计稿预设。
  const TvDesignPreset({
    required this.label,
    required this.designSize,
  });

  /// 预设展示标签。
  final String label;

  /// 固定设计稿尺寸；自动模式为空。
  final Size? designSize;

  /// 解析当前视口应使用的设计稿预设。
  TvDesignPreset resolve(Size viewportSize) {
    if (this != TvDesignPreset.auto) {
      return this;
    }

    // 先匹配更高档位，保证大屏设备优先使用更接近的设计基准。
    if (viewportSize.width >= TvDesignPreset.qhd1440.designSize!.width &&
        viewportSize.height >= TvDesignPreset.qhd1440.designSize!.height) {
      return TvDesignPreset.qhd1440;
    }

    // 其次匹配 1080p，保持主流电视分辨率下的默认设计比例。
    if (viewportSize.width >= TvDesignPreset.fullHd1080.designSize!.width &&
        viewportSize.height >= TvDesignPreset.fullHd1080.designSize!.height) {
      return TvDesignPreset.fullHd1080;
    }

    // 更小分辨率统一回退到 720p 设计稿，避免低分屏整体显大一圈。
    return TvDesignPreset.hd720;
  }
}

/// TV 设计画布指标。
///
/// 统一暴露当前 TV 页面相对于设计稿预设的缩放结果。
class TvDesignMetrics {
  /// 创建设计画布指标。
  const TvDesignMetrics({
    required this.scale,
    required this.designSize,
    required this.viewportSize,
    required this.preset,
    required this.resolvedPreset,
  });

  /// 当前视口相对于设计稿的缩放比例。
  final double scale;

  /// 设计稿逻辑尺寸。
  final Size designSize;

  /// 当前实际视口尺寸。
  final Size viewportSize;

  /// 当前配置的设计稿预设。
  final TvDesignPreset preset;

  /// 当前视口下最终生效的设计稿预设。
  final TvDesignPreset resolvedPreset;
}

/// TV 端设计画布。
///
/// 支持自动和固定设计稿预设，并在较小分辨率下整体等比缩小，保持 TV
/// 页面在不同设备上的视觉比例稳定。
class TvDesignCanvas extends StatelessWidget {
  /// 创建设计画布包装。
  const TvDesignCanvas({
    super.key,
    required this.child,
    this.preset = TvDesignPreset.fullHd1080,
  });

  /// 子树内容。
  final Widget child;

  /// 当前使用的设计稿预设。
  final TvDesignPreset preset;

  /// 读取当前设计画布指标。
  static TvDesignMetrics of(BuildContext context) {
    return maybeOf(context) ??
        TvDesignMetrics(
          scale: 1,
          designSize: TvDesignPreset.fullHd1080.designSize!,
          viewportSize: MediaQuery.sizeOf(context),
          preset: TvDesignPreset.fullHd1080,
          resolvedPreset: TvDesignPreset.fullHd1080,
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
        // 无约束场景统一回退到 1080p 基准，避免测试或弹窗拿到无穷大尺寸。
        final viewportSize = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : TvDesignPreset.fullHd1080.designSize!.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : TvDesignPreset.fullHd1080.designSize!.height,
        );
        final resolvedPreset = preset.resolve(viewportSize);
        final designSize = resolvedPreset.designSize!;
        final designWidth = designSize.width;
        final designHeight = designSize.height;
        final widthScale = viewportSize.width / designWidth;
        final heightScale = viewportSize.height / designHeight;
        // 高分屏不额外放大，只在较小分辨率下按比例缩小。
        final scale =
            math.min(1.0, math.min(widthScale, heightScale)).toDouble();
        final metrics = TvDesignMetrics(
          scale: scale,
          designSize: designSize,
          viewportSize: viewportSize,
          preset: preset,
          resolvedPreset: resolvedPreset,
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
                            size: Size(designWidth, designHeight),
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
