import 'package:flutter/material.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 直播页。
///
/// 当前阶段先提供独立占位页，避免继续复用其它页面索引。
class TvLiveScreen extends StatelessWidget {
  /// 创建 TV 直播页。
  const TvLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _TvLiveDevelopingPlaceholder(),
    );
  }
}

/// TV 直播页开发中占位内容。
class _TvLiveDevelopingPlaceholder extends StatelessWidget {
  /// 创建直播占位内容。
  const _TvLiveDevelopingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Text(
      '正在开发',
      style: FontUtils.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}
