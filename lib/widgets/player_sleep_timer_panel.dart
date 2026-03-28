import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlayerSleepTimerPanel extends StatefulWidget {
  final ThemeData theme;
  final bool sideSheet;
  final DateTime? scheduledAt;
  final bool canExitApp;
  final double? backgroundOpacity;
  final Future<bool> Function(int minutes) onSetMinutes;
  final Future<bool> Function(TimeOfDay time) onSetTimeOfDay;
  final Future<bool> Function() onCancelTimer;

  const PlayerSleepTimerPanel({
    super.key,
    required this.theme,
    required this.sideSheet,
    required this.canExitApp,
    this.backgroundOpacity,
    required this.onSetMinutes,
    required this.onSetTimeOfDay,
    required this.onCancelTimer,
    this.scheduledAt,
  });

  @override
  State<PlayerSleepTimerPanel> createState() => _PlayerSleepTimerPanelState();
}

class _PlayerSleepTimerPanelState extends State<PlayerSleepTimerPanel> {
  static const int _minCustomMinutes = 1;
  static const int _maxCustomMinutes = 300;

  final TextEditingController _desktopCustomMinutesController =
      TextEditingController();
  late final FixedExtentScrollController _customMinutesScrollController;
  late TimeOfDay _selectedClockTime;
  late int _selectedCustomMinutes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedClockTime = _initialClockTime();
    _selectedCustomMinutes = _initialCustomMinutes();
    _customMinutesScrollController = FixedExtentScrollController(
      initialItem: _selectedCustomMinutes - _minCustomMinutes,
    );
  }

  @override
  void dispose() {
    _desktopCustomMinutesController.dispose();
    _customMinutesScrollController.dispose();
    super.dispose();
  }

  bool get _isDarkMode => widget.theme.brightness == Brightness.dark;

  bool get _usesInlinePickers {
    switch (widget.theme.platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return false;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  double get _backgroundOpacity =>
      widget.backgroundOpacity ?? (_isDarkMode ? 0.85 : 0.95);

  Color get _backgroundColor => _isDarkMode
      ? Colors.black.withValues(alpha: _backgroundOpacity.clamp(0.0, 1.0))
      : Colors.white.withValues(alpha: _backgroundOpacity.clamp(0.0, 1.0));

  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;

  Color get _subTextColor => _isDarkMode ? Colors.white54 : Colors.black54;

  TimeOfDay _initialClockTime() {
    if (widget.scheduledAt != null) {
      final scheduledAt = widget.scheduledAt!;
      return TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute);
    }

    final now = DateTime.now();
    final minuteOffset = now.minute % 5 == 0 ? 0 : 5 - (now.minute % 5);
    final rounded = now.add(Duration(minutes: minuteOffset));
    return TimeOfDay(hour: rounded.hour, minute: rounded.minute);
  }

  int _initialCustomMinutes() {
    if (widget.scheduledAt != null) {
      final remainingMinutes =
          widget.scheduledAt!.difference(DateTime.now()).inMinutes;
      if (remainingMinutes <= _minCustomMinutes) {
        return _minCustomMinutes;
      }
      if (remainingMinutes >= _maxCustomMinutes) {
        return _maxCustomMinutes;
      }
      return remainingMinutes;
    }

    return 45;
  }

  Future<void> _handleMinutes(int minutes) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final success = await widget.onSetMinutes(minutes);
      if (success && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleDesktopCustomMinutes() async {
    final minutes = int.tryParse(_desktopCustomMinutesController.text.trim());
    if (minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于 0 的分钟数')),
      );
      return;
    }

    await _handleMinutes(minutes);
  }

  Future<void> _handleCustomMinutes() async =>
      _handleMinutes(_selectedCustomMinutes);

  Future<void> _handleClockTime() async {
    if (_submitting) return;

    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now.replacing(minute: (now.minute ~/ 5) * 5),
      builder: (context, child) {
        return Theme(
          data: widget.theme.copyWith(
            colorScheme: _isDarkMode
                ? const ColorScheme.dark(
                    primary: Colors.green,
                    surface: Color(0xFF171717),
                  )
                : const ColorScheme.light(
                    primary: Colors.green,
                    surface: Colors.white,
                  ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: _backgroundColor,
              dialHandColor: Colors.green,
              dayPeriodColor:
                  WidgetStateColor.resolveWith((states) => Colors.green),
              hourMinuteTextColor: _textColor,
              helpTextStyle: TextStyle(color: _subTextColor),
              dialTextColor: _textColor,
              entryModeIconColor: _textColor,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final success = await widget.onSetTimeOfDay(picked);
      if (success && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleCancel() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final success = await widget.onCancelTimer();
      if (success && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  DateTime _clockTimeToDateTime(TimeOfDay time) {
    return DateTime(2024, 1, 1, time.hour, time.minute);
  }

  String _formatScheduledAt(DateTime value) {
    final now = DateTime.now();
    final sameDay = now.year == value.year &&
        now.month == value.month &&
        now.day == value.day;
    final prefix = sameDay ? '今天' : '明天';
    return '$prefix ${DateFormat('HH:mm').format(value)}';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _subTextColor,
        fontSize: 13,
      ),
    );
  }

  Widget _buildQuickButton(String label, int minutes) {
    return Expanded(
      child: SizedBox(
        height: 40,
        child: FilledButton.tonal(
          onPressed: _submitting ? null : () => _handleMinutes(minutes),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.14),
            foregroundColor: Colors.green,
            disabledBackgroundColor: Colors.green.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Future<void> _handleInlineClockTime() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final success = await widget.onSetTimeOfDay(_selectedClockTime);
      if (success && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _formatInlineTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildInlinePickerContainer(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDarkMode ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  Widget _buildInlineTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInlinePickerContainer(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '上下波动选择关闭时间点',
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatInlineTime(_selectedClockTime),
                style: TextStyle(
                  color: _textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness:
                        _isDarkMode ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: _clockTimeToDateTime(_selectedClockTime),
                    onDateTimeChanged: (value) {
                      setState(() {
                        _selectedClockTime = TimeOfDay(
                          hour: value.hour,
                          minute: value.minute,
                        );
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _submitting ? null : _handleInlineClockTime,
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: const Text('设置时间'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.14),
              foregroundColor: Colors.green,
              disabledBackgroundColor: Colors.green.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineMinutesPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInlinePickerContainer(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '上下波动选择分钟数',
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_selectedCustomMinutes 分钟',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness:
                        _isDarkMode ? Brightness.dark : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(
                        color: _textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  child: CupertinoPicker.builder(
                    scrollController: _customMinutesScrollController,
                    itemExtent: 38,
                    useMagnifier: true,
                    magnification: 1.08,
                    squeeze: 1.15,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedCustomMinutes = _minCustomMinutes + index;
                      });
                    },
                    childCount: _maxCustomMinutes - _minCustomMinutes + 1,
                    itemBuilder: (context, index) {
                      final value = _minCustomMinutes + index;
                      return Center(
                        child: Text('$value 分钟'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _handleCustomMinutes,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('设置分钟数'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: widget.sideSheet
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              )
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.sideSheet ? 16 : 20,
              8,
              widget.sideSheet ? 8 : 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '定时关闭',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: widget.sideSheet ? 17 : 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: _textColor, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.scheduledAt != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '当前已设置',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '预计 ${_formatScheduledAt(widget.scheduledAt!)} ${widget.canExitApp ? '退出应用' : '停止播放'}',
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _handleCancel,
                            icon:
                                const Icon(Icons.timer_off_outlined, size: 18),
                            label: const Text('取消定时'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textColor,
                              side: BorderSide(
                                color: _isDarkMode
                                    ? Colors.white24
                                    : Colors.black12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildSectionTitle('快捷设置'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildQuickButton('30 分钟', 30),
                      const SizedBox(width: 8),
                      _buildQuickButton('60 分钟', 60),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickButton('90 分钟', 90),
                      const SizedBox(width: 8),
                      _buildQuickButton('120 分钟', 120),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('自定义分钟数'),
                  const SizedBox(height: 10),
                  if (_usesInlinePickers)
                    _buildInlineMinutesPicker()
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _desktopCustomMinutesController,
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: _textColor),
                            decoration: InputDecoration(
                              hintText: '输入分钟数，例如 45',
                              hintStyle: TextStyle(color: _subTextColor),
                              filled: true,
                              fillColor: _isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: _isDarkMode
                                      ? Colors.white24
                                      : Colors.black12,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: _isDarkMode
                                      ? Colors.white24
                                      : Colors.black12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.green),
                              ),
                            ),
                            onSubmitted: (_) => _handleDesktopCustomMinutes(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : _handleDesktopCustomMinutes,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('设置'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('指定时间'),
                  const SizedBox(height: 10),
                  if (_usesInlinePickers)
                    _buildInlineTimePicker()
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _handleClockTime,
                        icon: const Icon(Icons.schedule_outlined, size: 18),
                        label: const Text('选择关闭时间点'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textColor,
                          side: BorderSide(
                            color:
                                _isDarkMode ? Colors.white24 : Colors.black12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
