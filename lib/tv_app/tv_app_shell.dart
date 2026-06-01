import 'package:flutter/material.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/screens/tv_home_screen.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_design_canvas.dart';

/// TV 端应用根壳。
///
/// Android TV 启动后进入该入口，后续 TV 专属页面都挂载在这里。
class TvAppShell extends StatefulWidget {
  /// 创建 TV 端应用根壳。
  const TvAppShell({super.key});

  @override
  State<TvAppShell> createState() => _TvAppShellState();
}

class _TvAppShellState extends State<TvAppShell> {
  /// TV 主题色服务。
  final TvThemeService _themeService = TvThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.load();
    PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
  }

  @override
  void dispose() {
    _themeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvBackHandler(
      autofocus: true,
      child: TvDesignCanvas(
        preset: TvDesignPreset.hd720,
        child: TvTheme(
          service: _themeService,
          child: const TvHomeScreen(),
        ),
      ),
    );
  }
}
