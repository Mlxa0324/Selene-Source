import 'package:flutter/material.dart';
import '../utils/device_utils.dart';

/// 画面比例类型
enum VideoFitType {
  contain, // 适应
  fill, // 填充
  fitWidth, // 宽度
  fitHeight, // 高度
  aspectRatio16_9, // 16:9
}

/// 播放设置面板
class PlayerSettingsPanel extends StatelessWidget {
  final ThemeData theme;
  final VideoFitType currentFitType;
  final double currentLongPressSpeed;
  final bool showTimeWhenControlsHidden;
  final Function(VideoFitType) onFitTypeChanged;
  final Function(double) onLongPressSpeedChanged;
  final Function(bool) onShowTimeChanged;

  const PlayerSettingsPanel({
    super.key,
    required this.theme,
    required this.currentFitType,
    required this.currentLongPressSpeed,
    required this.showTimeWhenControlsHidden,
    required this.onFitTypeChanged,
    required this.onLongPressSpeedChanged,
    required this.onShowTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1c1c1e) : Colors.white,
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '设置',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 画面设置
                  _buildSectionTitle('画面', isDarkMode),
                  const SizedBox(height: 12),
                  _buildFitTypeSelector(isDarkMode, context),

                  const SizedBox(height: 24),

                  // 长按倍速
                  _buildSectionTitle('长按倍速', isDarkMode),
                  const SizedBox(height: 12),
                  _buildLongPressSpeedSelector(isDarkMode, context),

                  const SizedBox(height: 24),

                  // 播放时间显示开关
                  _buildTimeDisplaySwitch(isDarkMode, context),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildFitTypeSelector(bool isDarkMode, BuildContext context) {
    final fitTypes = [
      (VideoFitType.contain, '适应'),
      (VideoFitType.fill, '填充'),
      (VideoFitType.fitWidth, '宽度'),
      (VideoFitType.fitHeight, '高度'),
      (VideoFitType.aspectRatio16_9, '16:9'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: fitTypes.map((item) {
        final isSelected = currentFitType == item.$1;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: item.$2,
          onTap: () {
            onFitTypeChanged(item.$1);
          },
        );
      }).toList(),
    );
  }

  Widget _buildLongPressSpeedSelector(bool isDarkMode, BuildContext context) {
    final speeds = [2.0, 2.5, 3.0];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: speeds.map((speed) {
        final isSelected = (currentLongPressSpeed - speed).abs() < 0.01;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: '${speed}x',
          onTap: () {
            onLongPressSpeedChanged(speed);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTimeDisplaySwitch(bool isDarkMode, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '显示播放时间',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '控制按钮隐藏时仍显示播放时间',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // 播放时间显示开关
        // 按钮有点大，我想小一点
        Transform.scale(
          scale: 0.85, // 调整这个值来改变大小（0.7 表示原始大小的70%）
          child: Switch(
            value: showTimeWhenControlsHidden,
            onChanged: onShowTimeChanged,
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.3),
          ),
        )
      ],
    );
  }
}

/// 带 hover 效果的设置项（PC 端专用）
class _SettingsItemWithHover extends StatefulWidget {
  final bool isSelected;
  final bool isDarkMode;
  final String label;
  final VoidCallback onTap;

  const _SettingsItemWithHover({
    required this.isSelected,
    required this.isDarkMode,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SettingsItemWithHover> createState() => _SettingsItemWithHoverState();
}

class _SettingsItemWithHoverState extends State<_SettingsItemWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.green.withValues(alpha: 0.2)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode
                        ? const Color(0xFF1A3D2E)
                        : const Color(0xFFE8F5E9))
                    : (widget.isDarkMode ? Colors.grey[800] : Colors.grey[200])),
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(color: Colors.green, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected
                    ? Colors.green
                    : (widget.isDarkMode ? Colors.white : Colors.black87),
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
