import 'package:flutter/material.dart';
import '../models/danmaku_model.dart';
import '../services/danmaku_service.dart';
import '../utils/device_utils.dart';

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
                  '弹幕设置',
                  style: widget.theme.textTheme.titleLarge?.copyWith(
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
                  // 弹幕开关
                  _buildSwitchRow('弹幕开关', _settings.enabled, isDarkMode, (v) {
                    _updateSettings(_settings.copyWith(enabled: v));
                  }),

                  const SizedBox(height: 24),

                  // 字体大小
                  _buildSectionTitle('字体大小', isDarkMode),
                  const SizedBox(height: 12),
                  _buildFontSizeSelector(isDarkMode),

                  const SizedBox(height: 24),

                  // 透明度
                  _buildSectionTitle('透明度', isDarkMode),
                  const SizedBox(height: 12),
                  _buildOpacitySelector(isDarkMode),

                  const SizedBox(height: 24),

                  // 弹幕速度
                  _buildSectionTitle('弹幕速度', isDarkMode),
                  const SizedBox(height: 12),
                  _buildDurationSelector(isDarkMode),

                  const SizedBox(height: 24),

                  // 弹幕类型过滤
                  _buildSectionTitle('弹幕类型', isDarkMode),
                  const SizedBox(height: 12),
                  _buildSwitchRow('隐藏滚动弹幕', _settings.hideScroll, isDarkMode, (v) {
                    _updateSettings(_settings.copyWith(hideScroll: v));
                  }),
                  const SizedBox(height: 8),
                  _buildSwitchRow('隐藏顶部弹幕', _settings.hideTop, isDarkMode, (v) {
                    _updateSettings(_settings.copyWith(hideTop: v));
                  }),
                  const SizedBox(height: 8),
                  _buildSwitchRow('隐藏底部弹幕', _settings.hideBottom, isDarkMode, (v) {
                    _updateSettings(_settings.copyWith(hideBottom: v));
                  }),

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

  Widget _buildSwitchRow(String title, bool value, bool isDarkMode, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeSelector(bool isDarkMode) {
    final sizes = [
      (16.0, '小'),
      (20.0, '中'),
      (24.0, '大'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sizes.map((item) {
        final isSelected = (_settings.fontSize - item.$1).abs() < 0.1;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: item.$2,
          onTap: () => _updateSettings(_settings.copyWith(fontSize: item.$1)),
        );
      }).toList(),
    );
  }

  Widget _buildOpacitySelector(bool isDarkMode) {
    final opacities = [0.5, 0.75, 1.0];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: opacities.map((opacity) {
        final isSelected = (_settings.opacity - opacity).abs() < 0.01;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: '${(opacity * 100).toInt()}%',
          onTap: () => _updateSettings(_settings.copyWith(opacity: opacity)),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector(bool isDarkMode) {
    final durations = [
      (6, '慢'),
      (8, '中'),
      (10, '快'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: durations.map((item) {
        final isSelected = _settings.duration == item.$1;
        return _SettingsItemWithHover(
          isSelected: isSelected,
          isDarkMode: isDarkMode,
          label: item.$2,
          onTap: () => _updateSettings(_settings.copyWith(duration: item.$1.toDouble())),
        );
      }).toList(),
    );
  }
}

/// 带 hover 效果的设置项
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
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.green.withOpacity(0.2)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode ? const Color(0xFF1A3D2E) : const Color(0xFFE8F5E9))
                    : (widget.isDarkMode ? Colors.grey[800] : Colors.grey[200])),
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected ? Border.all(color: Colors.green, width: 2) : null,
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
