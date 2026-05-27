import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 顶部导航变更回调。
///
/// [index] 为新选中的导航下标。
typedef TvTopNavChanged = void Function(int index);

/// TV 顶部导航确认键回调。
///
/// [index] 为当前获得焦点的导航下标，返回 true 表示页面已处理确认行为。
typedef TvTopNavPressed = bool Function(int index);

/// TV 顶部导航方向键回调。
///
/// [index] 为当前获得焦点的导航下标。
typedef TvTopNavArrowUp = void Function(int index);

/// TV 顶部导航下方向键回调。
///
/// [index] 为当前获得焦点的导航下标，返回 true 表示页面已处理焦点移动。
typedef TvTopNavArrowDown = bool Function(int index);

/// TV 顶部导航控制器。
///
/// 用于页面级返回键把焦点显式送回当前选中的顶部入口。
class TvTopNavController {
  /// 当前绑定的顶部导航状态。
  _TvTopNavState? _state;

  /// 顶部导航当前是否持有焦点。
  bool get hasFocus => _state?._hasAnyTopNavFocus ?? false;

  /// 请求焦点回到当前选中的顶部入口。
  bool requestSelectedFocus() {
    return _state?._requestSelectedFocus() ?? false;
  }

  /// 绑定顶部导航状态。
  void _attach(_TvTopNavState state) {
    _state = state;
  }

  /// 解绑顶部导航状态。
  void _detach(_TvTopNavState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

/// TV 顶部导航快捷操作。
class TvTopNavAction {
  /// 创建 TV 顶部导航快捷操作。
  const TvTopNavAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  /// 操作稳定标识，用于测试和焦点定位。
  final String key;

  /// 操作文案。
  final String label;

  /// 操作图标。
  final IconData icon;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 是否为当前选中页面。
  final bool selected;
}

/// TV 首页顶部导航。
///
/// 展示主分类菜单和右侧快捷入口，并支持遥控器焦点。
class TvTopNav extends StatefulWidget {
  /// 创建 TV 顶部导航。
  ///
  /// [tabs] 为导航文案列表。
  /// [selectedIndex] 为当前选中下标。
  /// [onChanged] 为切换回调。
  /// [onSearchPressed] 为右上角搜索入口回调。
  /// [onHistoryPressed] 为播放历史快捷入口回调。
  /// [onFavoritesPressed] 为收藏夹快捷入口回调。
  /// [onSettingsPressed] 为设置快捷入口回调。
  /// [onTabPressed] 为菜单项获焦后按确认键回调。
  /// [onTabArrowUp] 为菜单项获焦后按上方向键兜底回调。
  /// [onTabArrowDown] 为菜单项获焦后按下方向键回调。
  const TvTopNav({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.controller,
    this.onSearchPressed,
    this.onHistoryPressed,
    this.onFavoritesPressed,
    this.onSettingsPressed,
    this.onTabPressed,
    this.onTabArrowUp,
    this.onTabArrowDown,
  });

  /// 导航文案列表。
  final List<String> tabs;

  /// 当前选中下标。
  final int selectedIndex;

  /// 导航切换回调。
  final TvTopNavChanged onChanged;

  /// 顶部导航控制器。
  final TvTopNavController? controller;

  /// 搜索入口点击回调。
  final VoidCallback? onSearchPressed;

  /// 播放历史快捷入口点击回调。
  final VoidCallback? onHistoryPressed;

  /// 收藏夹快捷入口点击回调。
  final VoidCallback? onFavoritesPressed;

  /// 设置快捷入口点击回调。
  final VoidCallback? onSettingsPressed;

  /// 菜单项确认键回调。
  final TvTopNavPressed? onTabPressed;

  /// 菜单项上方向键回调。
  final TvTopNavArrowUp? onTabArrowUp;

  /// 菜单项下方向键回调。
  final TvTopNavArrowDown? onTabArrowDown;

  @override
  State<TvTopNav> createState() => _TvTopNavState();
}

class _TvTopNavState extends State<TvTopNav> {
  /// 顶部菜单项焦点节点。
  final List<FocusNode> _focusNodes = [];

  /// 顶部菜单项定位 Key，用于让当前选中项滚动到可见区域。
  final List<GlobalKey> _itemKeys = [];

  /// 顶部搜索入口焦点节点。
  final List<FocusNode> _actionFocusNodes = [];

  /// 顶部快捷入口定位 Key。
  final List<GlobalKey> _actionKeys = [];

  /// 顶部菜单当前是否已有任一菜单项获得焦点。
  bool _navHasFocus = false;

  /// 当前是否正在把外部焦点重定向到已选菜单项。
  bool _redirectingToSelected = false;

  /// 最近一次从主菜单进入快捷按钮区的菜单下标。
  int? _lastActionSourceTabIndex;

  /// 当前时间刷新定时器。
  Timer? _clockTimer;

  /// 顶部右侧展示的当前时间。
  late String _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = _formatCurrentTime(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _currentTime = _formatCurrentTime(DateTime.now()));
    });
    _syncFocusableItems();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant TvTopNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusableItems();
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _clockTimer?.cancel();
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final node in _actionFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// 将时间格式化为 TV 顶部右侧的短时间。
  static String _formatCurrentTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 同步顶部菜单焦点节点数量。
  void _syncFocusableItems() {
    while (_focusNodes.length < widget.tabs.length) {
      _focusNodes.add(FocusNode());
      _itemKeys.add(GlobalKey());
    }
    while (_focusNodes.length > widget.tabs.length) {
      _focusNodes.removeLast().dispose();
      _itemKeys.removeLast();
    }
    final actionCount = _actions.length;
    while (_actionFocusNodes.length < actionCount) {
      _actionFocusNodes.add(FocusNode());
      _actionKeys.add(GlobalKey());
    }
    while (_actionFocusNodes.length > actionCount) {
      _actionFocusNodes.removeLast().dispose();
      _actionKeys.removeLast();
    }
  }

  /// 处理顶部菜单项焦点变化。
  void _handleTabFocusChange(int index, bool hasFocus) {
    if (!hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _navHasFocus = _hasAnyTopNavFocus;
      });
      return;
    }

    final enteringFromOutside = !_navHasFocus;
    _navHasFocus = true;

    // 从内容区回到顶部菜单时，总是先回到当前选中项，避免就近菜单误切页。
    if (enteringFromOutside &&
        (!_isMainTabSelected || index != widget.selectedIndex)) {
      _redirectFocusToSelected();
      return;
    }

    if (_redirectingToSelected) {
      _redirectingToSelected = false;
      return;
    }

    // 顶部菜单内部左右移动时，焦点到哪个菜单就切到哪个菜单。
    //
    // “直播”现在是独立页面，但仍保留按上进入右上角快捷区的过渡能力。
    if (index != widget.selectedIndex) {
      widget.onChanged(index);
    }
  }

  /// 把焦点重定向到当前选中的顶部菜单项。
  void _redirectFocusToSelected() {
    _requestSelectedFocus();
  }

  /// 请求焦点回到当前选中的顶部入口。
  bool _requestSelectedFocus() {
    final target = _selectedFocusTarget;
    if (target == null) {
      return false;
    }
    _redirectingToSelected = true;
    _requestFocusTarget(target);
    return true;
  }

  /// 请求焦点并把目标滚动到可见区域。
  void _requestFocusTarget(_TopNavFocusTarget target) {
    target.focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = target.itemKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 160),
          alignment: 0.5,
        );
      }
    });
  }

  /// 从主分类进入右上角快捷按钮。
  void _focusFirstAction(int sourceTabIndex) {
    if (_actionFocusNodes.isEmpty || _actionKeys.isEmpty) {
      return;
    }
    _lastActionSourceTabIndex = sourceTabIndex;
    _navHasFocus = true;
    _requestFocusTarget(
      _TopNavFocusTarget(
        focusNode: _actionFocusNodes.first,
        itemKey: _actionKeys.first,
      ),
    );
  }

  /// 从右上角快捷按钮回到来源主菜单项。
  void _focusActionSourceTab() {
    final selectedMainIndex = _isMainTabSelected ? widget.selectedIndex : null;
    final sourceIndex =
        _lastActionSourceTabIndex ?? selectedMainIndex ?? _liveTabIndex;
    if (sourceIndex == null ||
        sourceIndex < 0 ||
        sourceIndex >= _focusNodes.length) {
      return;
    }
    _requestFocusTarget(
      _TopNavFocusTarget(
        focusNode: _focusNodes[sourceIndex],
        itemKey: _itemKeys[sourceIndex],
      ),
    );
  }

  /// 直播主菜单项下标。
  int? get _liveTabIndex {
    final index = widget.tabs.indexOf('直播');
    return index < 0 ? null : index;
  }

  /// 当前选中页对应的顶部焦点目标。
  _TopNavFocusTarget? get _selectedFocusTarget {
    if (_isMainTabSelected &&
        widget.selectedIndex >= 0 &&
        widget.selectedIndex < _focusNodes.length) {
      return _TopNavFocusTarget(
        focusNode: _focusNodes[widget.selectedIndex],
        itemKey: _itemKeys[widget.selectedIndex],
      );
    }
    final actionIndex = _selectedActionIndex;
    if (actionIndex != null && actionIndex < _actionFocusNodes.length) {
      return _TopNavFocusTarget(
        focusNode: _actionFocusNodes[actionIndex],
        itemKey: _actionKeys[actionIndex],
      );
    }
    return null;
  }

  /// 当前选中页是否属于左侧主菜单。
  ///
  /// 右上角快捷入口使用独立页面下标，不能再把播放历史等页面误判成“直播”菜单选中态。
  bool get _isMainTabSelected {
    final quickActionIndex = _selectedActionIndex;
    if (quickActionIndex != null) {
      return false;
    }
    return widget.selectedIndex >= 0 &&
        widget.selectedIndex < widget.tabs.length;
  }

  /// 当前选中页对应的快捷入口下标。
  int? get _selectedActionIndex {
    switch (widget.selectedIndex) {
      case 6:
        final index = _actions.indexWhere((action) => action.key == 'history');
        return index < 0 ? null : index;
      case 7:
        final index =
            _actions.indexWhere((action) => action.key == 'favorites');
        return index < 0 ? null : index;
      case 8:
        final index = _actions.indexWhere((action) => action.key == 'settings');
        return index < 0 ? null : index;
      default:
        return null;
    }
  }

  /// 顶部导航整体是否已有焦点。
  bool get _hasAnyTopNavFocus {
    return _focusNodes.any((node) => node.hasFocus) ||
        _actionFocusNodes.any((node) => node.hasFocus);
  }

  /// 处理快捷入口焦点变化。
  void _handleActionFocusChange(bool hasFocus) {
    if (!hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navHasFocus = _hasAnyTopNavFocus;
        }
      });
      return;
    }

    final enteringFromOutside = !_navHasFocus;
    _navHasFocus = true;

    // 从内容区回到顶部时，快捷入口也要优先回到当前选中入口。
    if (enteringFromOutside) {
      _redirectFocusToSelected();
      return;
    }

    if (_redirectingToSelected) {
      _redirectingToSelected = false;
    }
  }

  /// 处理顶部菜单项确认键。
  void _handleTabPressed(int index) {
    final handled = widget.onTabPressed?.call(index) ?? false;
    if (handled) {
      return;
    }
    widget.onChanged(index);
  }

  /// 顶部快捷入口列表。
  List<TvTopNavAction> get _actions {
    return [
      if (widget.onSearchPressed != null)
        TvTopNavAction(
          key: 'search',
          label: '搜索',
          icon: LucideIcons.search,
          onPressed: widget.onSearchPressed!,
        ),
      if (widget.onHistoryPressed != null)
        TvTopNavAction(
          key: 'history',
          label: '播放历史',
          icon: LucideIcons.history,
          selected: widget.selectedIndex == 6,
          onPressed: widget.onHistoryPressed!,
        ),
      if (widget.onFavoritesPressed != null)
        TvTopNavAction(
          key: 'favorites',
          label: '收藏夹',
          icon: LucideIcons.heart,
          selected: widget.selectedIndex == 7,
          onPressed: widget.onFavoritesPressed!,
        ),
      if (widget.onSettingsPressed != null)
        TvTopNavAction(
          key: 'settings',
          label: '设置',
          icon: LucideIcons.settings,
          selected: widget.selectedIndex == 8,
          onPressed: widget.onSettingsPressed!,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    final actions = _actions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TvLayout.pageHorizontalPadding,
        28,
        TvLayout.pageHorizontalPadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                key: const ValueKey('tv-top-nav-logo'),
                'IvyTV',
                style: FontUtils.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 32),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        key: const ValueKey('tv-top-nav-actions'),
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            textDirection: TextDirection.ltr,
                            children: actions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final action = entry.value;
                              return Padding(
                                key: _actionKeys[index],
                                padding: EdgeInsets.only(
                                  left: index == 0 ? 0 : 10,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final edgeShakeKey =
                                        GlobalKey<TvEdgeShakeState>();
                                    final isLastItem =
                                        index == actions.length - 1;
                                    return TvEdgeShake(
                                      key: edgeShakeKey,
                                      child: _TvTopNavActionButton(
                                        action: action,
                                        focusNode: _actionFocusNodes[index],
                                        onFocusChanged:
                                            _handleActionFocusChange,
                                        onArrowDown: _focusActionSourceTab,
                                        onArrowRight: isLastItem
                                            ? () => edgeShakeKey.currentState
                                                ?.shake(AxisDirection.right)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(width: 24),
              Text(
                key: const ValueKey('tv-top-nav-clock'),
                _currentTime,
                style: FontUtils.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB6C2BF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('tv-top-nav-main-tabs'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final title = entry.value;
                      final selected =
                          _isMainTabSelected && index == widget.selectedIndex;
                      final onTabArrowDown = widget.onTabArrowDown;

                      return Padding(
                        key: _itemKeys[index],
                        padding: const EdgeInsets.only(right: 12),
                        child: TvFocusable(
                          focusNode: _focusNodes[index],
                          autofocus: index == 0,
                          onFocusChanged: (hasFocus) =>
                              _handleTabFocusChange(index, hasFocus),
                          onPressed: () => _handleTabPressed(index),
                          onArrowUp: actions.isNotEmpty
                              ? () => _focusFirstAction(index)
                              : widget.onTabArrowUp == null
                                  ? null
                                  : () => widget.onTabArrowUp!(index),
                          onArrowDown: onTabArrowDown == null
                              ? null
                              : () {
                                  final handled = onTabArrowDown(index);
                                  if (!handled) {
                                    _focusNodes[index].focusInDirection(
                                      TraversalDirection.down,
                                    );
                                  }
                                },
                          builder: (context, hasFocus) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? palette.accent
                                    : hasFocus
                                        ? palette.focusFill
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasFocus
                                      ? palette.focus
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                title,
                                style: FontUtils.poppins(
                                  fontSize: 18,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? palette.selectedText
                                      : const Color(0xFFD9E2E0),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶部焦点目标。
class _TopNavFocusTarget {
  /// 创建顶部焦点目标。
  const _TopNavFocusTarget({
    required this.focusNode,
    required this.itemKey,
  });

  /// 焦点节点。
  final FocusNode focusNode;

  /// 定位 Key。
  final GlobalKey itemKey;
}

/// TV 顶部导航快捷按钮。
class _TvTopNavActionButton extends StatelessWidget {
  /// 创建 TV 顶部导航快捷按钮。
  const _TvTopNavActionButton({
    required this.action,
    required this.focusNode,
    required this.onFocusChanged,
    this.onArrowDown,
    this.onArrowRight,
  });

  /// 快捷操作。
  final TvTopNavAction action;

  /// 焦点节点。
  final FocusNode focusNode;

  /// 焦点变化回调。
  final ValueChanged<bool> onFocusChanged;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      key: ValueKey('tv-top-nav-action-${action.key}'),
      focusNode: focusNode,
      onFocusChanged: onFocusChanged,
      onPressed: action.onPressed,
      onArrowDown: onArrowDown,
      onArrowRight: onArrowRight,
      builder: (context, hasFocus) {
        final active = hasFocus || action.selected;
        return Semantics(
          button: true,
          label: action.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: action.selected
                  ? palette.accent
                  : hasFocus
                      ? palette.focusFill
                      : const Color(0xFF272C30),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: hasFocus ? palette.focus : Colors.transparent,
                width: hasFocus ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  size: 19,
                  color: action.selected ? palette.selectedText : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  action.label,
                  style: FontUtils.poppins(
                    fontSize: 16,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: action.selected
                        ? palette.selectedText
                        : const Color(0xFFE6ECEA),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
