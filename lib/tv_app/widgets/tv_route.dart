import 'package:flutter/material.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';

/// TV 页面路由工具。
///
/// 统一封装零动画路由，并保证新页面继续继承当前 TV 主题作用域和设计视口。
class TvRoute {
  /// 私有构造，避免工具类被实例化。
  const TvRoute._();

  /// 构建一个零动画的 TV 页面路由。
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
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
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
