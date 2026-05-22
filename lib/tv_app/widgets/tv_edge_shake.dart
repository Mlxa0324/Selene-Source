import 'dart:async';

import 'package:flutter/material.dart';

/// TV 边界抖动组件。
///
/// 用于遥控器焦点已经到达列表边缘时，给当前卡片一个轻微方向反馈。
class TvEdgeShake extends StatefulWidget {
  /// 创建 TV 边界抖动组件。
  const TvEdgeShake({
    super.key,
    required this.child,
  });

  /// 需要播放抖动动画的子组件。
  final Widget child;

  @override
  State<TvEdgeShake> createState() => TvEdgeShakeState();
}

/// TV 边界抖动状态。
class TvEdgeShakeState extends State<TvEdgeShake>
    with SingleTickerProviderStateMixin {
  /// 当前抖动方向。
  AxisDirection _direction = AxisDirection.right;

  /// 是否允许重新触发抖动。
  bool _canShake = true;

  /// 抖动冷却计时器。
  Timer? _cooldownTimer;

  /// 长按方向键时的抖动冷却间隔。
  static const Duration cooldownDuration = Duration(milliseconds: 520);

  /// 抖动动画控制器。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// 抖动位移动画。
  late final Animation<double> _offsetAnimation = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0, end: 8)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 24,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 8, end: -6)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: -6, end: 4)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 24,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 4, end: 0)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 22,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 按指定方向播放边界抖动。
  void shake(AxisDirection direction) {
    if (!_canShake) {
      return;
    }

    _direction = direction;
    _canShake = false;
    _controller.forward(from: 0);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldownDuration, () {
      if (!mounted) {
        return;
      }
      _canShake = true;
    });
  }

  /// 根据边界方向计算位移。
  Offset _resolveOffset(double value) {
    switch (_direction) {
      case AxisDirection.left:
        return Offset(-value, 0);
      case AxisDirection.right:
        return Offset(value, 0);
      case AxisDirection.up:
        return Offset(0, -value);
      case AxisDirection.down:
        return Offset(0, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          key: const ValueKey('tv-edge-shake'),
          offset: _resolveOffset(_offsetAnimation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
