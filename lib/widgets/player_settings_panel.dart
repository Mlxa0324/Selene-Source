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
    final backgroundColor = isDarkMode 
        ? Colors.black.withOpacity(0.85) 
        : Colors.white.withOpacity(0.95);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '播放设置',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 画面设置
                  _buildSectionHeader('画面比例', subTextColor),
                  const SizedBox(height: 10),
                  _buildFitTypeSelector(isDarkMode),

                  const SizedBox(height: 20),

                  // 长按倍速
                  _buildSectionHeader('长按倍速', subTextColor),
                  const SizedBox(height: 10),
                  _buildLongPressSpeedSelector(isDarkMode),

                  const SizedBox(height: 20),

                  // 播放时间显示开关
                  _buildTimeDisplaySwitch(isDarkMode, textColor, subTextColor),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 13,
      ),
    );
  }

  Widget _buildFitTypeSelector(bool isDarkMode) {
    final fitTypes = [
      (VideoFitType.contain, '适应'),
      (VideoFitType.fill, '填充'),
      (VideoFitType.fitWidth, '宽度'),
      (VideoFitType.fitHeight, '高度'),
      (VideoFitType.aspectRatio16_9, '16:9'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fitTypes.map((item) {
        final isSelected = currentFitType == item.$1;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: item.$2,
          onTap: () => onFitTypeChanged(item.$1),
        );
      }).toList(),
    );
  }

  Widget _buildLongPressSpeedSelector(bool isDarkMode) {
    final speeds = [2.0, 2.5, 3.0];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: speeds.map((speed) {
        final isSelected = (currentLongPressSpeed - speed).abs() < 0.01;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: '${speed}x',
          onTap: () => onLongPressSpeedChanged(speed),
        );
      }).toList(),
    );
  }

  Widget _buildTimeDisplaySwitch(bool isDarkMode, Color textColor, Color subTextColor) {
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
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Text(
                '隐藏控制栏时显示时间',
                style: TextStyle(
                  fontSize: 11,
                  color: subTextColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 30,
          child: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: showTimeWhenControlsHidden,
              onChanged: onShowTimeChanged,
              activeColor: Colors.green,
              activeTrackColor: Colors.green.withOpacity(0.3),
            ),
          ),
        )
      ],
    );
  }
}

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
        if (DeviceUtils.isPC()) setState(() => _isHovering = true);
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) setState(() => _isHovering = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 65, // 缩小宽度
          height: 32, // 缩小高度
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.green.withOpacity(0.2)
                : (widget.isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(6),
            border: widget.isSelected ? Border.all(color: Colors.green, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected
                    ? Colors.green
                    : (widget.isDarkMode ? Colors.white70 : Colors.black87),
                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}