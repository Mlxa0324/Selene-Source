import 'package:flutter/material.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';

/// TV 页面路由工具。
///
/// 统一封装轻量 TV 路由过渡，并保证新页面继续继承当前 TV 主题作用域和设计视口。
class TvRoute {
  /// 私有构造，避免工具类被实例化。
  const TvRoute._();

  /// TV 页面统一过渡时长。
  ///
  /// 180ms 属于大屏场景下比较常见、也相对克制的切页时长，
  /// 能弱化“生硬瞬切”的感觉，又不会拖慢返回响应。
  static const Duration _transitionDuration = Duration(milliseconds: 180);

  /// TV 页面轻量位移的起始偏移。
  ///
  /// 只做非常轻微的纵向滑入，营造“上一层页面浮上来”的感觉，
  /// 同时避免大幅横向位移带来的眩晕和性能浪费。
  static const Offset _transitionBeginOffset = Offset(0, 0.018);

  /// 构建一个带轻量过渡的 TV 页面路由。
  static PageRoute<T> page<T extends Object?>({
    required BuildContext context,
    required Widget child,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (routeContext, animation, secondaryAnimation) =>
          TvTheme.wrapScope(
        context: context,
        child: child,
      ),
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      transitionsBuilder: (
        routeContext,
        animation,
        secondaryAnimation,
        routeChild,
      ) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final opacityAnimation = Tween<double>(
          begin: 0,
          end: 1,
        ).animate(curvedAnimation);
        final positionAnimation = Tween<Offset>(
          begin: _transitionBeginOffset,
          end: Offset.zero,
        ).animate(curvedAnimation);

        return FadeTransition(
          opacity: opacityAnimation,
          child: SlideTransition(
            position: positionAnimation,
            child: routeChild,
          ),
        );
      },
    );
  }

  /// 推入一个新的 TV 页面路由。
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget child,
  ) {
    return Navigator.of(context).push<T>(
      page<T>(context: context, child: child),
    );
  }

  /// 用新的 TV 页面替换当前路由。
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget child, {
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      page<T>(context: context, child: child),
      result: result,
    );
  }
}
