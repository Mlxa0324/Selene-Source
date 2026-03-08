import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../utils/device_utils.dart';

/// 画面比例类型
enum VideoFitType {
  contain, // 适应
  fill, // 填充
  fitWidth, // 宽度
  fitHeight, // 高度
}

/// 播放进度显示模式
enum ProgressDisplayMode {
  none, // 关闭
  time, // 时间
  bar, // 进度条
}

/// 播放设置面板
class PlayerSettingsPanel extends StatelessWidget {
  final ThemeData theme;
  final VideoFitType currentFitType;
  final double currentLongPressSpeed;
  final ProgressDisplayMode progressMode;
  final bool showSystemTime;
  final int skipIntro;
  final int skipOutro;
  final int videoPosition; // 当前播放位置（秒）
  final int videoDuration; // 总时长（秒）
  final Function(VideoFitType) onFitTypeChanged;
  final Function(double) onLongPressSpeedChanged;
  final Function(ProgressDisplayMode) onProgressModeChanged;
  final Function(bool) onShowSystemTimeChanged;
  final Function(int) onSkipIntroChanged;
  final Function(int) onSkipOutroChanged;

  const PlayerSettingsPanel({
    super.key,
    required this.theme,
    required this.currentFitType,
    required this.currentLongPressSpeed,
    required this.progressMode,
    required this.showSystemTime,
    required this.skipIntro,
    required this.skipOutro,
    required this.videoPosition,
    required this.videoDuration,
    required this.onFitTypeChanged,
    required this.onLongPressSpeedChanged,
    required this.onProgressModeChanged,
    required this.onShowSystemTimeChanged,
    required this.onSkipIntroChanged,
    required this.onSkipOutroChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final isIOS = Platform.isIOS;
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

                  if (!isIOS) ...[
                    _buildSectionHeader('长按倍速', subTextColor),
                    const SizedBox(height: 10),
                    _buildLongPressSpeedSelector(isDarkMode),
                    const SizedBox(height: 20),
                  ],

                  // 自动跳过
                  _buildSectionHeader('自动跳过', subTextColor),
                  const SizedBox(height: 10),
                  _buildSkipSlider('跳过片头', skipIntro, 300, onSkipIntroChanged,
                      textColor, subTextColor, isIntro: true),
                  _buildSkipSlider('跳过片尾', skipOutro, 300, onSkipOutroChanged,
                      textColor, subTextColor, isIntro: false),

                  const SizedBox(height: 20),

                  // 功能增强
                  _buildSectionHeader('功能增强', subTextColor),
                  // const SizedBox(height: 10),
                  // _buildSystemTimeSwitch(isDarkMode, textColor, subTextColor),

                  const SizedBox(height: 20),

                  // 播放进度
                  _buildSectionHeader('显示播放进度 (控制栏隐藏时)', subTextColor),
                  const SizedBox(height: 10),
                  _buildProgressModeSelector(isDarkMode),

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

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '${m}m';
    return '${m}m${s}s';
  }

  Widget _buildSkipSlider(
    String label,
    int value,
    double max,
    Function(int) onChanged,
    Color textColor,
    Color subTextColor, {
    required bool isIntro,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 65,
                child: Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.green,
                    inactiveTrackColor: textColor.withOpacity(0.1),
                    thumbColor: Colors.green,
                    overlayColor: Colors.green.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: value.toDouble().clamp(0.0, max),
                    min: 0,
                    max: max,
                    divisions: max.toInt(),
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  _formatSeconds(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 65),
            child: Row(
              children: [
                _buildCompactButton(
                  icon: Icons.remove,
                  onTap: () => onChanged((value - 5).clamp(0, max.toInt())),
                  color: subTextColor,
                ),
                const SizedBox(width: 8),
                _buildCompactButton(
                  icon: Icons.add,
                  onTap: () => onChanged((value + 5).clamp(0, max.toInt())),
                  color: subTextColor,
                ),
                const Spacer(),
                _buildTextButton(
                  '拾取',
                  onTap: () {
                    if (isIntro) {
                      onChanged(videoPosition.clamp(0, max.toInt()));
                    } else {
                      if (videoDuration > 0) {
                        onChanged((videoDuration - videoPosition)
                            .clamp(0, max.toInt()));
                      }
                    }
                  },
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _buildTextButton(
                  '清除',
                  onTap: () => onChanged(0),
                  color: subTextColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildTextButton(
    String label, {
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFitTypeSelector(bool isDarkMode) {
    final fitTypes = [
      (VideoFitType.contain, '适应'),
      (VideoFitType.fill, '填充'),
      (VideoFitType.fitWidth, '宽度'),
      (VideoFitType.fitHeight, '高度'),
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
    final speeds = Platform.isIOS ? [2.0] : [2.0, 2.5, 3.0];

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

  Widget _buildProgressModeSelector(bool isDarkMode) {
    final modes = [
      (ProgressDisplayMode.none, '关闭'),
      (ProgressDisplayMode.time, '时间'),
      (ProgressDisplayMode.bar, '进度条'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((item) {
        final isSelected = progressMode == item.$1;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: item.$2,
          onTap: () => onProgressModeChanged(item.$1),
        );
      }).toList(),
    );
  }

  Widget _buildSystemTimeSwitch(
      bool isDarkMode, Color textColor, Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '显示系统时间',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Text(
                '控制栏隐藏时在右下角显示',
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
              value: showSystemTime,
              onChanged: onShowSystemTimeChanged,
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
          width: 65,
          height: 32,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.green.withOpacity(0.2)
                : (widget.isDarkMode
                    ? Colors.white12
                    : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(6),
            border: widget.isSelected
                ? Border.all(color: Colors.green, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected
                    ? Colors.green
                    : (widget.isDarkMode ? Colors.white70 : Colors.black87),
                fontWeight:
                    widget.isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
