import 'package:flutter/material.dart';
import 'package:selene/models/app_device_type.dart';
import 'package:selene/services/app_device_service.dart';

/// 设备类型解析函数。
///
/// 启动分流使用该函数决定进入 TV 端还是普通端。
typedef AppDeviceTypeResolver = Future<AppDeviceType> Function();

/// 应用启动分流组件。
///
/// Android TV 进入 TV 独立入口，其他设备继续进入现有普通端入口。
class AppBootstrap extends StatefulWidget {
  /// 创建应用启动分流组件。
  ///
  /// [normalBuilder] 构建普通端入口。
  /// [tvBuilder] 构建 TV 端入口。
  /// [resolveDeviceType] 可在测试中注入设备类型。
  const AppBootstrap({
    super.key,
    required this.normalBuilder,
    required this.tvBuilder,
    this.resolveDeviceType,
  });

  /// 普通端入口构建器。
  final WidgetBuilder normalBuilder;

  /// TV 端入口构建器。
  final WidgetBuilder tvBuilder;

  /// 可注入的设备类型解析函数。
  final AppDeviceTypeResolver? resolveDeviceType;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  /// 启动阶段设备类型判断任务。
  late Future<AppDeviceType> _deviceTypeFuture;

  @override
  void initState() {
    super.initState();
    _deviceTypeFuture = _resolveDeviceType();
  }

  /// 执行设备类型判断。
  Future<AppDeviceType> _resolveDeviceType() {
    return widget.resolveDeviceType?.call() ??
        const AppDeviceService().resolveDeviceType();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDeviceType>(
      future: _deviceTypeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppBootstrapLoading();
        }

        // 只有明确识别为 TV 时才进入 TV 入口，其他情况全部降级为普通端。
        if (snapshot.data == AppDeviceType.tv) {
          return widget.tvBuilder(context);
        }

        return widget.normalBuilder(context);
      },
    );
  }
}

/// 启动分流加载态。
///
/// 用轻量加载页避免设备判断期间出现空白屏。
class _AppBootstrapLoading extends StatelessWidget {
  /// 创建启动分流加载态。
  const _AppBootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
