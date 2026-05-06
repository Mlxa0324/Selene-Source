import 'package:flutter/material.dart';
import '../models/danmaku_model.dart';
import '../services/danmaku_service.dart';

/// 弹幕设置面板
class DanmakuSettingsPanel extends StatefulWidget {
  final ThemeData theme;
  final DanmakuSettings settings;
  final Function(DanmakuSettings) onSettingsChanged;

  const DanmakuSettingsPanel({
    super.key,
    required this.theme,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<DanmakuSettingsPanel> createState() => _DanmakuSettingsPanelState();
}

class _DanmakuSettingsPanelState extends State<DanmakuSettingsPanel> {
  late DanmakuSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _updateSettings(DanmakuSettings newSettings) {
    setState(() => _settings = newSettings);
    widget.onSettingsChanged(newSettings);
    DanmakuService().saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '弹幕设置',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, color: textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                  const SizedBox(height: 8),

                  // 显示设置
                  _buildSectionHeader('显示设置', subTextColor),
                  const SizedBox(height: 12),
                  _buildSliderRow(
                    '不透明度',
                    _settings.opacity,
                    0.1,
                    1.0,
                    textColor,
                    subTextColor,
                    (v) => _updateSettings(_settings.copyWith(opacity: v)),
                    valueLabel: '${(_settings.opacity * 100).toInt()}%',
                  ),
                  _buildSliderRow(
                    '弹幕缩放',
                    _settings.scale,
                    0.5,
                    2.0,
                    textColor,
                    subTextColor,
                    (v) => _updateSettings(_settings.copyWith(scale: v)),
                    valueLabel: '${_settings.scale.toStringAsFixed(1)}x',
                  ),
                  _buildSliderRow(
                    '弹幕速度',
                    _settings.duration,
                    3.0,
                    15.0,
                    textColor,
                    subTextColor,
                    (v) => _updateSettings(_settings.copyWith(duration: v)),
                    valueLabel:
                        '${(18 - _settings.duration).toStringAsFixed(1)}x',
                    reverse: true,
                  ),
                  _buildSliderRow(
                    '行间距',
                    _settings.lineSpacing,
                    0.5,
                    4.0,
                    textColor,
                    subTextColor,
                    (v) => _updateSettings(_settings.copyWith(lineSpacing: v)),
                    valueLabel: '${_settings.lineSpacing.toStringAsFixed(1)}x',
                  ),
                  _buildSliderRow(
                    '字体粗细',
                    _settings.fontWeight,
                    1.0,
                    3.0,
                    textColor,
                    subTextColor,
                    (v) => _updateSettings(_settings.copyWith(fontWeight: v)),
                    valueLabel: '${_settings.fontWeight.toStringAsFixed(1)}x',
                  ),

                  const SizedBox(height: 24),

                  // 显示区域
                  _buildSectionHeader('显示区域', subTextColor),
                  const SizedBox(height: 12),
                  _buildSliderRow(
                    '占满屏幕',
                    _settings.displayArea,
                    0.25,
                    1.0,
                    textColor,
                    subTextColor,
                    (v) => _updateSettings(_settings.copyWith(displayArea: v)),
                    valueLabel: _getDisplayAreaLabel(_settings.displayArea),
                  ),

                  // 功能开关
                  _buildSwitchRow('防止弹幕重叠', _settings.preventOverlap, textColor,
                      (v) {
                    _updateSettings(_settings.copyWith(preventOverlap: v));
                  }),
                  _buildSwitchRow('同步视频速度', _settings.syncVideoSpeed, textColor,
                      (v) {
                    _updateSettings(_settings.copyWith(syncVideoSpeed: v));
                  }),

                  const SizedBox(height: 24),

                  // 屏蔽设置
                  _buildSectionHeader('屏蔽设置', subTextColor),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBlockTextButton(
                          '滚动', _settings.hideScroll, isDarkMode, (v) {
                        _updateSettings(_settings.copyWith(hideScroll: v));
                      }),
                      _buildBlockTextButton('顶部', _settings.hideTop, isDarkMode,
                          (v) {
                        _updateSettings(_settings.copyWith(hideTop: v));
                      }),
                      _buildBlockTextButton(
                          '底部', _settings.hideBottom, isDarkMode, (v) {
                        _updateSettings(_settings.copyWith(hideBottom: v));
                      }),
                      _buildBlockTextButton(
                          '彩色', _settings.hideColor, isDarkMode, (v) {
                        _updateSettings(_settings.copyWith(hideColor: v));
                      }),
                    ],
                  ),

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

  Widget _buildSwitchRow(
      String title, bool value, Color textColor, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
          SizedBox(
            height: 30,
            child: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    Color textColor,
    Color subTextColor,
    Function(double) onChanged, {
    required String valueLabel,
    bool reverse = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.green,
                inactiveTrackColor: textColor.withOpacity(0.1),
                thumbColor: Colors.green,
                overlayColor: Colors.green.withOpacity(0.2),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockTextButton(
      String text, bool isSelected, bool isDarkMode, Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!isSelected),
      child: Container(
        width: 65,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withOpacity(0.2)
              : (isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: Colors.green, width: 1) : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected
                  ? Colors.green
                  : (isDarkMode ? Colors.white70 : Colors.black54),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayAreaLabel(double value) {
    if (value >= 1.0) return '占满';
    if (value <= 0.25) return '1/4';
    if (value <= 0.5) return '1/2';
    if (value <= 0.75) return '3/4';
    return '${(value * 100).toInt()}%';
  }
}
