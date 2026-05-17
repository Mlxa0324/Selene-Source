import 'package:flutter/material.dart';
import '../utils/device_utils.dart';

/// 切换播放源/集数时的加载蒙版组件
class SwitchLoadingOverlay extends StatelessWidget {
  final bool isVisible;
  final String message;
  final AnimationController animationController;
  final VoidCallback? onBackPressed;
  final bool isFullscreen; // 💡 新增：标记是否处于全屏

  const SwitchLoadingOverlay({
    super.key,
    required this.isVisible,
    required this.message,
    required this.animationController,
    this.onBackPressed,
    this.isFullscreen = false, // 💡 默认非全屏
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    final accentColor = Theme.of(context).colorScheme.primary;

    // 💡 仅在全屏模式下且非 PC 平台才需要计算状态栏高度
    final double topPadding = (isFullscreen && !DeviceUtils.isPC()) 
        ? MediaQuery.of(context).padding.top 
        : 0;

    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // 左上角返回按钮
            if (onBackPressed != null)
              Positioned(
                top: 4 + topPadding, // 💡 只有全屏时才会真正下移
                left: 8.0,
                child: DeviceUtils.isPC()
                    ? _HoverBackButton(
                        onTap: onBackPressed!,
                        iconColor: Colors.white,
                      )
                    : GestureDetector(
                        onTap: onBackPressed,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
              ),
            // 中心加载内容
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 加载动画 - 与页面加载蒙版保持一致
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 旋转的背景方块（半透明绿色）
                      RotationTransition(
                        turns: animationController,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      // 中间的图标容器
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(accentColor, Colors.white, 0.12)!,
                              accentColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Center(
                          child: Text(
                            '🎬',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 加载文案
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带 hover 效果的返回按钮（PC 端专用）
class _HoverBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color iconColor;

  const _HoverBackButton({
    required this.onTap,
    required this.iconColor,
  });

  @override
  State<_HoverBackButton> createState() => _HoverBackButtonState();
}

class _HoverBackButtonState extends State<_HoverBackButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: _isHovering
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.5),
                )
              : null,
          child: Icon(
            Icons.arrow_back,
            color: widget.iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
