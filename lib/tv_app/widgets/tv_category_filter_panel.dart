import 'package:flutter/material.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 分类筛选类型。
enum TvCategoryFilterKind {
  /// 电影分类。
  movie,

  /// 剧集分类。
  series,

  /// 动漫分类。
  anime,

  /// 综艺分类。
  variety,
}

/// TV 分类筛选选项。
class TvCategoryFilterOption {
  /// 创建 TV 分类筛选选项。
  const TvCategoryFilterOption({
    required this.label,
    required this.value,
  });

  /// 展示文案。
  final String label;

  /// 筛选值。
  final String value;
}

/// TV 分类筛选行数据。
class TvCategoryFilterRowData {
  /// 创建 TV 分类筛选行数据。
  const TvCategoryFilterRowData({
    required this.title,
    required this.options,
    this.defaultOptionValue,
  });

  /// 行标题。
  final String title;

  /// 横向筛选项。
  final List<TvCategoryFilterOption> options;

  /// 当前行的默认选中值。
  ///
  /// 当父级还没有保存该行筛选结果时，优先使用这个值回显。
  final String? defaultOptionValue;
}

/// TV 分类筛选选择回调。
typedef TvCategoryFilterChanged = void Function(
  String rowTitle,
  TvCategoryFilterOption option,
);

/// TV 分类筛选焦点变化回调。
typedef TvCategoryFilterFocusChanged = void Function(
  String rowTitle,
  TvCategoryFilterOption option,
);

/// TV 分类筛选面板展示模式。
enum TvCategoryFilterPanelMode {
  /// 展开完整筛选项。
  expanded,

  /// 收起为一行摘要。
  compact,
}

/// TV 分类筛选面板。
///
/// 用于电影、剧集、动漫、综艺分类页，按上键呼出后展示多行横向筛选项。
class TvCategoryFilterPanel extends StatefulWidget {
  /// 创建 TV 分类筛选面板。
  const TvCategoryFilterPanel({
    super.key,
    required this.kind,
    this.selectedOptions = const <String, TvCategoryFilterOption>{},
    this.preferredFocusOptionValues = const <String, String>{},
    this.mode = TvCategoryFilterPanelMode.expanded,
    this.preferredFocusRowTitle,
    this.onChanged,
    this.onFocusChanged,
  });

  /// 当前分类类型。
  final TvCategoryFilterKind kind;

  /// 当前已确认的筛选项。
  final Map<String, TvCategoryFilterOption> selectedOptions;

  /// 当前各筛选行优先回到的焦点值。
  ///
  /// 面板从摘要态重新展开时，会优先回到该行上一次停留的筛选项。
  final Map<String, String> preferredFocusOptionValues;

  /// 当前面板展示模式。
  final TvCategoryFilterPanelMode mode;

  /// 面板展开后优先回到的筛选行标题。
  ///
  /// 从 Grid 区域回到筛选区时，优先回到更贴近当前分类结果的筛选行。
  final String? preferredFocusRowTitle;

  /// 筛选变化回调。
  final TvCategoryFilterChanged? onChanged;

  /// 筛选项焦点变化回调。
  final TvCategoryFilterFocusChanged? onFocusChanged;

  @override
  State<TvCategoryFilterPanel> createState() => _TvCategoryFilterPanelState();
}

class _TvCategoryFilterPanelState extends State<TvCategoryFilterPanel> {
  /// 展开态左侧保留页面对齐，右侧贴齐屏幕边缘。
  static const double _expandedLeftPadding = TvLayout.pageHorizontalPadding;

  /// 展开态右侧不再额外预留留白，让横向筛选列表直接贴边。
  static const double _expandedRightPadding = 0;

  /// 展开态顶部留白。
  static const double _expandedTopPadding = 16;

  /// 展开态底部留白。
  static const double _expandedBottomPadding = 14;

  /// 摘要态上下留白。
  static const EdgeInsets _compactPadding = EdgeInsets.fromLTRB(
    TvLayout.pageHorizontalPadding,
    8,
    TvLayout.pageHorizontalPadding,
    12,
  );

  /// 每个筛选项的稳定焦点节点。
  ///
  /// 父级刷新筛选结果时保持当前选中项焦点，避免回退到本行“全部”。
  final Map<String, FocusNode> _optionFocusNodes = {};

  /// 每一行横向滚动控制器。
  ///
  /// 用于完整构建所有筛选项后保持左右滚动能力，避免离屏选项无法获焦。
  final Map<String, ScrollController> _rowScrollControllers = {};

  /// 各筛选行最近一次停留的焦点值。
  ///
  /// 上下切换行时优先回到该行上一次停留位置，没有记录时再按当前列就近落点。
  final Map<String, String> _lastFocusedOptionValues = {};

  /// 当前面板行数据。
  List<TvCategoryFilterRowData> get _rows =>
      TvCategoryFilterOptions.rowsFor(widget.kind, widget.selectedOptions);

  /// 当前面板应该优先聚焦的行标题。
  String get _preferredFocusRowTitle {
    final preferredRowTitle = widget.preferredFocusRowTitle;
    final hasPreferredRow = preferredRowTitle != null &&
        _rows.any((row) => row.title == preferredRowTitle);
    return hasPreferredRow ? preferredRowTitle : _rows.first.title;
  }

  @override
  void initState() {
    super.initState();
    _lastFocusedOptionValues.addAll(widget.preferredFocusOptionValues);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _preferredOptionFocusNodeFor(_preferredFocusRowTitle).requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TvCategoryFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastFocusedOptionValues.addAll(widget.preferredFocusOptionValues);
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes.values) {
      node.dispose();
    }
    for (final controller in _rowScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 处理筛选项选中。
  void _selectOption(String rowTitle, TvCategoryFilterOption option) {
    _rememberFocusedOption(rowTitle, option);
    _optionFocusNodeFor(rowTitle, option.value).requestFocus();
    widget.onChanged?.call(rowTitle, option);
  }

  /// 判断当前选项是否选中。
  bool _isSelected(String rowTitle, TvCategoryFilterOption option) {
    return selectedOptionFor(rowTitle).value == option.value;
  }

  /// 获取指定行当前选中的筛选项，未选择时默认取第一项“全部”。
  TvCategoryFilterOption selectedOptionFor(String rowTitle) {
    final option = widget.selectedOptions[rowTitle];
    if (option != null) {
      return option;
    }
    final row = _rows.firstWhere(
      (item) => item.title == rowTitle,
      orElse: () => const TvCategoryFilterRowData(
        title: '',
        options: [TvCategoryFilterOption(label: '全部', value: 'all')],
      ),
    );
    final defaultValue = row.defaultOptionValue ?? row.options.first.value;
    return row.options.firstWhere(
      (item) => item.value == defaultValue,
      orElse: () => row.options.first,
    );
  }

  /// 获取指定筛选项的稳定焦点节点。
  FocusNode _optionFocusNodeFor(String rowTitle, String optionValue) {
    final key = '$rowTitle::$optionValue';
    return _optionFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'tv-filter-$key'),
    );
  }

  /// 获取指定行优先获焦的筛选项节点。
  FocusNode _preferredOptionFocusNodeFor(String rowTitle) {
    final row = _rows.firstWhere(
      (item) => item.title == rowTitle,
      orElse: () => const TvCategoryFilterRowData(
        title: '',
        options: [TvCategoryFilterOption(label: '全部', value: 'all')],
      ),
    );
    final preferredOption = _preferredOptionForRow(row);
    return _optionFocusNodeFor(row.title, preferredOption.value);
  }

  /// 获取指定行优先回到的筛选项。
  ///
  /// 先回到上一次停留项，没有记录时再回退到已选项或默认项。
  TvCategoryFilterOption _preferredOptionForRow(TvCategoryFilterRowData row) {
    final preferredValue = _lastFocusedOptionValues[row.title];
    if (preferredValue != null) {
      final preferredIndex = row.options.indexWhere(
        (item) => item.value == preferredValue,
      );
      if (preferredIndex >= 0) {
        return row.options[preferredIndex];
      }
    }
    return selectedOptionFor(row.title);
  }

  /// 获取指定行横向滚动控制器。
  ScrollController _rowScrollControllerFor(String rowTitle) {
    return _rowScrollControllers.putIfAbsent(
      rowTitle,
      () => ScrollController(keepScrollOffset: false),
    );
  }

  /// 记录筛选行最近一次停留的焦点项。
  void _rememberFocusedOption(
    String rowTitle,
    TvCategoryFilterOption option,
  ) {
    _lastFocusedOptionValues[rowTitle] = option.value;
    widget.onFocusChanged?.call(rowTitle, option);
  }

  /// 处理筛选项获焦。
  void _handleOptionFocused(String rowTitle, TvCategoryFilterOption option) {
    _rememberFocusedOption(rowTitle, option);
  }

  /// 在筛选行之间按上/下键切换焦点。
  ///
  /// 相邻行移动遵循遥控器的视觉就近习惯：优先找目标行当前视口内
  /// 与当前焦点中心 X 最近的筛选项，避免长行第 N 项机械跳到下一行第 N 项。
  void _moveFocusBetweenRows({
    required TvCategoryFilterRowData currentRow,
    required TvCategoryFilterOption currentOption,
    required TvCategoryFilterRowData targetRow,
  }) {
    final currentNode = _optionFocusNodeFor(
      currentRow.title,
      currentOption.value,
    );
    final nearestOption = _nearestVisibleOptionByCenterX(
      currentNode: currentNode,
      targetRow: targetRow,
    );
    if (nearestOption != null) {
      _optionFocusNodeFor(targetRow.title, nearestOption.value).requestFocus();
      return;
    }

    // 极端测试或首帧布局尚未完成时，退回到序号兜底，保证方向键不落空。
    final currentIndex = currentRow.options.indexWhere(
      (item) => item.value == currentOption.value,
    );
    final targetIndex = currentIndex < 0
        ? 0
        : currentIndex.clamp(0, targetRow.options.length - 1);
    _optionFocusNodeFor(
      targetRow.title,
      targetRow.options[targetIndex].value,
    ).requestFocus();
  }

  /// 按当前焦点中心 X 查找目标行当前视口内最近的筛选项。
  TvCategoryFilterOption? _nearestVisibleOptionByCenterX({
    required FocusNode currentNode,
    required TvCategoryFilterRowData targetRow,
  }) {
    final currentRect = _globalRectForFocusNode(currentNode);
    if (currentRect == null || targetRow.options.isEmpty) {
      return null;
    }

    final viewportRect = _rowViewportRectFor(targetRow.title);
    final referenceCenterX = viewportRect == null
        ? currentRect.center.dx
        : currentRect.center.dx.clamp(viewportRect.left, viewportRect.right);
    TvCategoryFilterOption? nearestOption;
    var nearestDistance = double.infinity;

    for (final option in targetRow.options) {
      final node = _optionFocusNodeFor(targetRow.title, option.value);
      final optionRect = _globalRectForFocusNode(node);
      if (optionRect == null) {
        continue;
      }
      if (viewportRect != null && !optionRect.overlaps(viewportRect)) {
        continue;
      }
      final distance = (optionRect.center.dx - referenceCenterX).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestOption = option;
      }
    }

    if (nearestOption != null || viewportRect == null) {
      return nearestOption;
    }

    // 目标行暂时没有可见候选时，再放宽到整行候选，避免快速滚动中焦点丢失。
    for (final option in targetRow.options) {
      final node = _optionFocusNodeFor(targetRow.title, option.value);
      final optionRect = _globalRectForFocusNode(node);
      if (optionRect == null) {
        continue;
      }
      final distance = (optionRect.center.dx - referenceCenterX).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestOption = option;
      }
    }
    return nearestOption;
  }

  /// 获取筛选行当前横向视口的全局矩形。
  Rect? _rowViewportRectFor(String rowTitle) {
    final controller = _rowScrollControllerFor(rowTitle);
    if (!controller.hasClients) {
      return null;
    }
    final viewportContext = controller.position.context.notificationContext;
    if (viewportContext == null) {
      return null;
    }
    final renderObject = viewportContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  /// 获取焦点节点对应控件的全局矩形。
  Rect? _globalRectForFocusNode(FocusNode node) {
    final nodeContext = node.context;
    if (nodeContext == null || !node.canRequestFocus) {
      return null;
    }
    final renderObject = nodeContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    // 分类页筛选摘要和面板也需要跟随全局 TV 背景，只保留轻量半透覆盖感。
    final panelBackgroundColor =
        TvTheme.backgroundOf(context).color.withAlpha(0xD0);
    if (widget.mode == TvCategoryFilterPanelMode.compact) {
      return Container(
        key: const ValueKey('tv-category-filter-summary'),
        padding: _compactPadding,
        color: panelBackgroundColor,
        child: _TvCategoryFilterCompactSummary(
          rows: rows,
          selectedOptions: widget.selectedOptions,
        ),
      );
    }

    return Container(
      key: const ValueKey('tv-category-filter-panel'),
      padding: const EdgeInsets.fromLTRB(
        _expandedLeftPadding,
        _expandedTopPadding,
        _expandedRightPadding,
        _expandedBottomPadding,
      ),
      color: panelBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in rows.asMap().entries) ...[
            Builder(
              builder: (context) {
                final index = entry.key;
                final row = entry.value;
                final previousRowTitle =
                    index > 0 ? rows[index - 1].title : null;
                final nextRowTitle =
                    index + 1 < rows.length ? rows[index + 1].title : null;

                return _TvCategoryFilterRow(
                  key: ValueKey('tv-filter-row-${row.title}'),
                  title: row.title,
                  options: row.options,
                  scrollController: _rowScrollControllerFor(row.title),
                  optionFocusNodeFor: (option) =>
                      _optionFocusNodeFor(row.title, option.value),
                  onArrowUp: previousRowTitle == null
                      ? null
                      : (option) {
                          final previousRow = rows[index - 1];
                          _moveFocusBetweenRows(
                            currentRow: row,
                            currentOption: option,
                            targetRow: previousRow,
                          );
                        },
                  onArrowDown: nextRowTitle == null
                      ? null
                      : (option) {
                          final nextRow = rows[index + 1];
                          _moveFocusBetweenRows(
                            currentRow: row,
                            currentOption: option,
                            targetRow: nextRow,
                          );
                        },
                  onSelected: (option) => _selectOption(row.title, option),
                  onFocused: (option) =>
                      _handleOptionFocused(row.title, option),
                  isSelected: (option) => _isSelected(row.title, option),
                );
              },
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// TV 分类筛选摘要条。
///
/// 用于列表浏览时保留当前筛选结果，避免完整筛选区长期占据过多高度。
class _TvCategoryFilterCompactSummary extends StatelessWidget {
  /// 创建 TV 分类筛选摘要条。
  const _TvCategoryFilterCompactSummary({
    required this.rows,
    required this.selectedOptions,
  });

  /// 当前分类支持的筛选行。
  final List<TvCategoryFilterRowData> rows;

  /// 已确认的筛选项。
  final Map<String, TvCategoryFilterOption> selectedOptions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2C3137),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF3B4046)),
            ),
            child: Text(
              '筛选',
              style: FontUtils.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView.separated(
              key: const ValueKey('tv-category-filter-summary-list'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final option = selectedOptions[row.title] ?? row.options.first;
                return _TvCategoryFilterSummaryChip(
                  key: ValueKey('tv-category-filter-summary-${row.title}'),
                  title: row.title,
                  value: option.label,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// TV 分类筛选摘要项。
class _TvCategoryFilterSummaryChip extends StatelessWidget {
  /// 创建 TV 分类筛选摘要项。
  const _TvCategoryFilterSummaryChip({
    super.key,
    required this.title,
    required this.value,
  });

  /// 行标题。
  final String title;

  /// 当前选中的摘要值。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF171A1C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30353A)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$title ',
              style: FontUtils.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF98A2A8),
              ),
            ),
            TextSpan(
              text: value,
              style: FontUtils.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TV 分类筛选选项配置。
class TvCategoryFilterOptions {
  const TvCategoryFilterOptions._();

  /// TV 分类页每次筛选请求的默认分页大小。
  static const int pageLimit = 25;

  /// 电影分类选项。
  static const List<TvCategoryFilterOption> movieCategoryOptions = [
    TvCategoryFilterOption(label: '全部', value: '全部'),
    TvCategoryFilterOption(label: '热门电影', value: '热门'),
    TvCategoryFilterOption(label: '最新电影', value: '最新'),
    TvCategoryFilterOption(label: '豆瓣高分', value: '豆瓣高分'),
    TvCategoryFilterOption(label: '冷门佳片', value: '冷门佳片'),
  ];

  /// 电影简单地区选项。
  static const List<TvCategoryFilterOption> movieSimpleRegionOptions = [
    TvCategoryFilterOption(label: '全部', value: '全部'),
    TvCategoryFilterOption(label: '华语', value: '华语'),
    TvCategoryFilterOption(label: '欧美', value: '欧美'),
    TvCategoryFilterOption(label: '韩国', value: '韩国'),
    TvCategoryFilterOption(label: '日本', value: '日本'),
  ];

  /// 剧集分类选项。
  static const List<TvCategoryFilterOption> seriesCategoryOptions = [
    TvCategoryFilterOption(label: '全部', value: '全部'),
    TvCategoryFilterOption(label: '最近热门', value: '最近热门'),
  ];

  /// 剧集简单类型选项。
  static const List<TvCategoryFilterOption> seriesSimpleTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'tv'),
    TvCategoryFilterOption(label: '国产', value: 'tv_domestic'),
    TvCategoryFilterOption(label: '欧美', value: 'tv_american'),
    TvCategoryFilterOption(label: '日本', value: 'tv_japanese'),
    TvCategoryFilterOption(label: '韩国', value: 'tv_korean'),
    TvCategoryFilterOption(label: '动漫', value: 'tv_animation'),
    TvCategoryFilterOption(label: '纪录片', value: 'tv_documentary'),
  ];

  /// 综艺分类选项。
  static const List<TvCategoryFilterOption> varietyCategoryOptions = [
    TvCategoryFilterOption(label: '全部', value: '全部'),
    TvCategoryFilterOption(label: '最近热门', value: '最近热门'),
  ];

  /// 综艺简单类型选项。
  static const List<TvCategoryFilterOption> varietySimpleTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'show'),
    TvCategoryFilterOption(label: '国内', value: 'show_domestic'),
    TvCategoryFilterOption(label: '国外', value: 'show_foreign'),
  ];

  /// 动漫分类选项。
  static const List<TvCategoryFilterOption> animeCategoryOptions = [
    TvCategoryFilterOption(label: '每日放送', value: '每日放送'),
    TvCategoryFilterOption(label: '番剧', value: '番剧'),
    TvCategoryFilterOption(label: '剧场版', value: '剧场版'),
  ];

  /// 动漫周几选项。
  static const List<TvCategoryFilterOption> weekdayOptions = [
    TvCategoryFilterOption(label: '周一', value: '1'),
    TvCategoryFilterOption(label: '周二', value: '2'),
    TvCategoryFilterOption(label: '周三', value: '3'),
    TvCategoryFilterOption(label: '周四', value: '4'),
    TvCategoryFilterOption(label: '周五', value: '5'),
    TvCategoryFilterOption(label: '周六', value: '6'),
    TvCategoryFilterOption(label: '周日', value: '7'),
  ];

  /// 通用高级类型选项。
  static const List<TvCategoryFilterOption> movieTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '喜剧', value: 'comedy'),
    TvCategoryFilterOption(label: '爱情', value: 'romance'),
    TvCategoryFilterOption(label: '动作', value: 'action'),
    TvCategoryFilterOption(label: '科幻', value: 'sci-fi'),
    TvCategoryFilterOption(label: '悬疑', value: 'suspense'),
    TvCategoryFilterOption(label: '犯罪', value: 'crime'),
    TvCategoryFilterOption(label: '惊悚', value: 'thriller'),
    TvCategoryFilterOption(label: '冒险', value: 'adventure'),
    TvCategoryFilterOption(label: '音乐', value: 'music'),
    TvCategoryFilterOption(label: '历史', value: 'history'),
    TvCategoryFilterOption(label: '奇幻', value: 'fantasy'),
    TvCategoryFilterOption(label: '恐怖', value: 'horror'),
    TvCategoryFilterOption(label: '战争', value: 'war'),
    TvCategoryFilterOption(label: '传记', value: 'biography'),
    TvCategoryFilterOption(label: '歌舞', value: 'musical'),
    TvCategoryFilterOption(label: '武侠', value: 'wuxia'),
    TvCategoryFilterOption(label: '情色', value: 'erotic'),
    TvCategoryFilterOption(label: '灾难', value: 'disaster'),
    TvCategoryFilterOption(label: '西部', value: 'western'),
    TvCategoryFilterOption(label: '纪录片', value: 'documentary'),
    TvCategoryFilterOption(label: '短片', value: 'short'),
  ];

  /// 剧集高级类型选项。
  static const List<TvCategoryFilterOption> seriesTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '喜剧', value: 'comedy'),
    TvCategoryFilterOption(label: '爱情', value: 'romance'),
    TvCategoryFilterOption(label: '悬疑', value: 'suspense'),
    TvCategoryFilterOption(label: '武侠', value: 'wuxia'),
    TvCategoryFilterOption(label: '古装', value: 'costume'),
    TvCategoryFilterOption(label: '家庭', value: 'family'),
    TvCategoryFilterOption(label: '犯罪', value: 'crime'),
    TvCategoryFilterOption(label: '科幻', value: 'sci-fi'),
    TvCategoryFilterOption(label: '恐怖', value: 'horror'),
    TvCategoryFilterOption(label: '历史', value: 'history'),
    TvCategoryFilterOption(label: '战争', value: 'war'),
    TvCategoryFilterOption(label: '动作', value: 'action'),
    TvCategoryFilterOption(label: '冒险', value: 'adventure'),
    TvCategoryFilterOption(label: '传记', value: 'biography'),
    TvCategoryFilterOption(label: '剧情', value: 'drama'),
    TvCategoryFilterOption(label: '奇幻', value: 'fantasy'),
    TvCategoryFilterOption(label: '惊悚', value: 'thriller'),
    TvCategoryFilterOption(label: '灾难', value: 'disaster'),
    TvCategoryFilterOption(label: '歌舞', value: 'musical'),
    TvCategoryFilterOption(label: '音乐', value: 'music'),
  ];

  /// 综艺高级类型选项。
  static const List<TvCategoryFilterOption> varietyTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '真人秀', value: 'reality'),
    TvCategoryFilterOption(label: '脱口秀', value: 'talkshow'),
    TvCategoryFilterOption(label: '音乐', value: 'music'),
    TvCategoryFilterOption(label: '歌舞', value: 'musical'),
  ];

  /// 动漫番剧类型选项。
  static const List<TvCategoryFilterOption> animeSeriesTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '黑色幽默', value: 'dark_humor'),
    TvCategoryFilterOption(label: '历史', value: 'history'),
    TvCategoryFilterOption(label: '歌舞', value: 'musical'),
    TvCategoryFilterOption(label: '励志', value: 'inspirational'),
    TvCategoryFilterOption(label: '恶搞', value: 'parody'),
    TvCategoryFilterOption(label: '治愈', value: 'healing'),
    TvCategoryFilterOption(label: '运动', value: 'sports'),
    TvCategoryFilterOption(label: '后宫', value: 'harem'),
    TvCategoryFilterOption(label: '情色', value: 'erotic'),
    TvCategoryFilterOption(label: '国漫', value: 'chinese_anime'),
    TvCategoryFilterOption(label: '人性', value: 'human_nature'),
    TvCategoryFilterOption(label: '悬疑', value: 'suspense'),
    TvCategoryFilterOption(label: '恋爱', value: 'love'),
    TvCategoryFilterOption(label: '魔幻', value: 'fantasy'),
    TvCategoryFilterOption(label: '科幻', value: 'sci_fi'),
  ];

  /// 动漫剧场版类型选项。
  static const List<TvCategoryFilterOption> animeMovieTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '定格动画', value: 'stop_motion'),
    TvCategoryFilterOption(label: '传记', value: 'biography'),
    TvCategoryFilterOption(label: '美国动画', value: 'us_animation'),
    TvCategoryFilterOption(label: '爱情', value: 'romance'),
    TvCategoryFilterOption(label: '黑色幽默', value: 'dark_humor'),
    TvCategoryFilterOption(label: '歌舞', value: 'musical'),
    TvCategoryFilterOption(label: '儿童', value: 'children'),
    TvCategoryFilterOption(label: '二次元', value: 'anime'),
    TvCategoryFilterOption(label: '动物', value: 'animal'),
    TvCategoryFilterOption(label: '青春', value: 'youth'),
    TvCategoryFilterOption(label: '历史', value: 'history'),
    TvCategoryFilterOption(label: '励志', value: 'inspirational'),
    TvCategoryFilterOption(label: '恶搞', value: 'parody'),
    TvCategoryFilterOption(label: '治愈', value: 'healing'),
    TvCategoryFilterOption(label: '运动', value: 'sports'),
    TvCategoryFilterOption(label: '后宫', value: 'harem'),
    TvCategoryFilterOption(label: '情色', value: 'erotic'),
    TvCategoryFilterOption(label: '人性', value: 'human_nature'),
    TvCategoryFilterOption(label: '悬疑', value: 'suspense'),
    TvCategoryFilterOption(label: '恋爱', value: 'love'),
    TvCategoryFilterOption(label: '魔幻', value: 'fantasy'),
    TvCategoryFilterOption(label: '科幻', value: 'sci_fi'),
  ];

  /// 通用地区选项。
  static const List<TvCategoryFilterOption> regionOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '华语', value: 'chinese'),
    TvCategoryFilterOption(label: '欧美', value: 'western'),
    TvCategoryFilterOption(label: '韩国', value: 'korean'),
    TvCategoryFilterOption(label: '日本', value: 'japanese'),
    TvCategoryFilterOption(label: '中国大陆', value: 'mainland_china'),
    TvCategoryFilterOption(label: '美国', value: 'usa'),
    TvCategoryFilterOption(label: '中国香港', value: 'hong_kong'),
    TvCategoryFilterOption(label: '中国台湾', value: 'taiwan'),
    TvCategoryFilterOption(label: '英国', value: 'uk'),
    TvCategoryFilterOption(label: '法国', value: 'france'),
    TvCategoryFilterOption(label: '德国', value: 'germany'),
    TvCategoryFilterOption(label: '意大利', value: 'italy'),
    TvCategoryFilterOption(label: '西班牙', value: 'spain'),
    TvCategoryFilterOption(label: '印度', value: 'india'),
    TvCategoryFilterOption(label: '泰国', value: 'thailand'),
    TvCategoryFilterOption(label: '俄罗斯', value: 'russia'),
    TvCategoryFilterOption(label: '加拿大', value: 'canada'),
    TvCategoryFilterOption(label: '澳大利亚', value: 'australia'),
    TvCategoryFilterOption(label: '爱尔兰', value: 'ireland'),
    TvCategoryFilterOption(label: '瑞典', value: 'sweden'),
    TvCategoryFilterOption(label: '巴西', value: 'brazil'),
    TvCategoryFilterOption(label: '丹麦', value: 'denmark'),
  ];

  /// 通用年份选项。
  static const List<TvCategoryFilterOption> yearOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '2020年代', value: '2020s'),
    TvCategoryFilterOption(label: '2025', value: '2025'),
    TvCategoryFilterOption(label: '2024', value: '2024'),
    TvCategoryFilterOption(label: '2023', value: '2023'),
    TvCategoryFilterOption(label: '2022', value: '2022'),
    TvCategoryFilterOption(label: '2021', value: '2021'),
    TvCategoryFilterOption(label: '2020', value: '2020'),
    TvCategoryFilterOption(label: '2019', value: '2019'),
    TvCategoryFilterOption(label: '2010年代', value: '2010s'),
    TvCategoryFilterOption(label: '2000年代', value: '2000s'),
    TvCategoryFilterOption(label: '90年代', value: '1990s'),
    TvCategoryFilterOption(label: '80年代', value: '1980s'),
    TvCategoryFilterOption(label: '70年代', value: '1970s'),
    TvCategoryFilterOption(label: '60年代', value: '1960s'),
    TvCategoryFilterOption(label: '更早', value: 'earlier'),
  ];

  /// 通用平台选项。
  static const List<TvCategoryFilterOption> platformOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '腾讯视频', value: 'tencent'),
    TvCategoryFilterOption(label: '爱奇艺', value: 'iqiyi'),
    TvCategoryFilterOption(label: '优酷', value: 'youku'),
    TvCategoryFilterOption(label: '湖南卫视', value: 'hunan_tv'),
    TvCategoryFilterOption(label: 'Netflix', value: 'netflix'),
    TvCategoryFilterOption(label: 'HBO', value: 'hbo'),
    TvCategoryFilterOption(label: 'BBC', value: 'bbc'),
    TvCategoryFilterOption(label: 'NHK', value: 'nhk'),
    TvCategoryFilterOption(label: 'CBS', value: 'cbs'),
    TvCategoryFilterOption(label: 'NBC', value: 'nbc'),
    TvCategoryFilterOption(label: 'tvN', value: 'tvn'),
  ];

  /// 电影排序选项。
  static const List<TvCategoryFilterOption> movieSortOptions = [
    TvCategoryFilterOption(label: '综合排序', value: 'T'),
    TvCategoryFilterOption(label: '近期热度', value: 'U'),
    TvCategoryFilterOption(label: '首映时间', value: 'R'),
    TvCategoryFilterOption(label: '高分优先', value: 'S'),
  ];

  /// 剧集排序选项。
  static const List<TvCategoryFilterOption> seriesSortOptions = [
    TvCategoryFilterOption(label: '综合排序', value: 'T'),
    TvCategoryFilterOption(label: '近期热度', value: 'U'),
    TvCategoryFilterOption(label: '首播时间', value: 'R'),
    TvCategoryFilterOption(label: '高分优先', value: 'S'),
  ];

  /// 综艺排序选项。
  static const List<TvCategoryFilterOption> varietySortOptions = [
    TvCategoryFilterOption(label: '综合排序', value: 'T'),
    TvCategoryFilterOption(label: '近期热度', value: 'U'),
    TvCategoryFilterOption(label: '首播时间', value: 'R'),
    TvCategoryFilterOption(label: '高分优先', value: 'S'),
  ];

  /// 动漫排序选项。
  static const List<TvCategoryFilterOption> animeSortOptions = [
    TvCategoryFilterOption(label: '综合排序', value: 'T'),
    TvCategoryFilterOption(label: '近期热度', value: 'U'),
    TvCategoryFilterOption(label: '首映时间', value: 'R'),
    TvCategoryFilterOption(label: '高分优先', value: 'S'),
  ];

  /// 根据分类返回筛选行。
  static List<TvCategoryFilterRowData> rowsFor(
    TvCategoryFilterKind kind,
    Map<String, TvCategoryFilterOption> selectedOptions,
  ) {
    switch (kind) {
      case TvCategoryFilterKind.movie:
        return _movieRows(selectedOptions);
      case TvCategoryFilterKind.series:
        return _seriesRows(selectedOptions);
      case TvCategoryFilterKind.anime:
        return _animeRows(selectedOptions);
      case TvCategoryFilterKind.variety:
        return _varietyRows(selectedOptions);
    }
  }

  /// 电影分类筛选行。
  static List<TvCategoryFilterRowData> _movieRows(
    Map<String, TvCategoryFilterOption> selectedOptions,
  ) {
    final category = selectedOptionFor(
      selectedOptions,
      '分类',
      movieCategoryOptions,
      defaultValue: '热门',
    );
    if (category.value == '全部') {
      return [
        const TvCategoryFilterRowData(
          title: '分类',
          options: movieCategoryOptions,
          defaultOptionValue: '热门',
        ),
        const TvCategoryFilterRowData(
          title: '类型',
          options: movieTypeOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '地区',
          options: regionOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '年代',
          options: yearOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '平台',
          options: platformOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '排序',
          options: movieSortOptions,
          defaultOptionValue: 'T',
        ),
      ];
    }

    return [
      const TvCategoryFilterRowData(
        title: '分类',
        options: movieCategoryOptions,
        defaultOptionValue: '热门',
      ),
      const TvCategoryFilterRowData(
        title: '地区',
        options: movieSimpleRegionOptions,
        defaultOptionValue: '全部',
      ),
    ];
  }

  /// 剧集分类筛选行。
  static List<TvCategoryFilterRowData> _seriesRows(
    Map<String, TvCategoryFilterOption> selectedOptions,
  ) {
    final category = selectedOptionFor(
      selectedOptions,
      '分类',
      seriesCategoryOptions,
      defaultValue: '最近热门',
    );
    if (category.value == '全部') {
      return [
        const TvCategoryFilterRowData(
          title: '分类',
          options: seriesCategoryOptions,
          defaultOptionValue: '最近热门',
        ),
        const TvCategoryFilterRowData(
          title: '类型',
          options: seriesTypeOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '地区',
          options: regionOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '年代',
          options: yearOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '平台',
          options: platformOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '排序',
          options: seriesSortOptions,
          defaultOptionValue: 'T',
        ),
      ];
    }

    return [
      const TvCategoryFilterRowData(
        title: '分类',
        options: seriesCategoryOptions,
        defaultOptionValue: '最近热门',
      ),
      const TvCategoryFilterRowData(
        title: '类型',
        options: seriesSimpleTypeOptions,
        defaultOptionValue: 'tv',
      ),
    ];
  }

  /// 综艺分类筛选行。
  static List<TvCategoryFilterRowData> _varietyRows(
    Map<String, TvCategoryFilterOption> selectedOptions,
  ) {
    final category = selectedOptionFor(
      selectedOptions,
      '分类',
      varietyCategoryOptions,
      defaultValue: '最近热门',
    );
    if (category.value == '全部') {
      return [
        const TvCategoryFilterRowData(
          title: '分类',
          options: varietyCategoryOptions,
          defaultOptionValue: '最近热门',
        ),
        const TvCategoryFilterRowData(
          title: '类型',
          options: varietyTypeOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '地区',
          options: regionOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '年代',
          options: yearOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '平台',
          options: platformOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '排序',
          options: varietySortOptions,
          defaultOptionValue: 'T',
        ),
      ];
    }

    return [
      const TvCategoryFilterRowData(
        title: '分类',
        options: varietyCategoryOptions,
        defaultOptionValue: '最近热门',
      ),
      const TvCategoryFilterRowData(
        title: '类型',
        options: varietySimpleTypeOptions,
        defaultOptionValue: 'show',
      ),
    ];
  }

  /// 动漫分类筛选行。
  static List<TvCategoryFilterRowData> _animeRows(
    Map<String, TvCategoryFilterOption> selectedOptions,
  ) {
    final category = selectedOptionFor(
      selectedOptions,
      '分类',
      animeCategoryOptions,
      defaultValue: '每日放送',
    );
    if (category.value == '每日放送') {
      return [
        const TvCategoryFilterRowData(
          title: '分类',
          options: animeCategoryOptions,
          defaultOptionValue: '每日放送',
        ),
        TvCategoryFilterRowData(
          title: '星期',
          options: weekdayOptions,
          defaultOptionValue: DateTime.now().weekday.toString(),
        ),
      ];
    }

    if (category.value == '番剧') {
      return [
        const TvCategoryFilterRowData(
          title: '分类',
          options: animeCategoryOptions,
          defaultOptionValue: '每日放送',
        ),
        const TvCategoryFilterRowData(
          title: '类型',
          options: animeSeriesTypeOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '地区',
          options: regionOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '年代',
          options: yearOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '平台',
          options: platformOptions,
          defaultOptionValue: 'all',
        ),
        const TvCategoryFilterRowData(
          title: '排序',
          options: animeSortOptions,
          defaultOptionValue: 'T',
        ),
      ];
    }

    return [
      const TvCategoryFilterRowData(
        title: '分类',
        options: animeCategoryOptions,
        defaultOptionValue: '每日放送',
      ),
      const TvCategoryFilterRowData(
        title: '类型',
        options: animeMovieTypeOptions,
        defaultOptionValue: 'all',
      ),
      const TvCategoryFilterRowData(
        title: '地区',
        options: regionOptions,
        defaultOptionValue: 'all',
      ),
      const TvCategoryFilterRowData(
        title: '年代',
        options: yearOptions,
        defaultOptionValue: 'all',
      ),
      const TvCategoryFilterRowData(
        title: '排序',
        options: animeSortOptions,
        defaultOptionValue: 'T',
      ),
    ];
  }

  /// 获取指定行当前选中的筛选项。
  static TvCategoryFilterOption selectedOptionFor(
    Map<String, TvCategoryFilterOption> selectedOptions,
    String rowTitle,
    List<TvCategoryFilterOption> options, {
    required String defaultValue,
  }) {
    final selected = selectedOptions[rowTitle];
    if (selected != null) {
      return selected;
    }
    return options.firstWhere(
      (option) => option.value == defaultValue,
      orElse: () => options.first,
    );
  }

  /// 获取指定行当前选中项的值。
  static String valueOrDefault(
    Map<String, TvCategoryFilterOption> selectedOptions,
    String rowTitle,
    List<TvCategoryFilterOption> options,
    String defaultValue,
  ) {
    return selectedOptionFor(
      selectedOptions,
      rowTitle,
      options,
      defaultValue: defaultValue,
    ).value;
  }

  /// 获取指定行当前选中项的请求标签，全部场景保持为 all。
  static String labelOrAll(
    Map<String, TvCategoryFilterOption> selectedOptions,
    String rowTitle,
    List<TvCategoryFilterOption> options,
  ) {
    final selected = selectedOptionFor(
      selectedOptions,
      rowTitle,
      options,
      defaultValue: 'all',
    );
    if (selected.value == 'all') {
      return 'all';
    }
    return selected.label;
  }
}

/// TV 分类筛选行。
class _TvCategoryFilterRow extends StatelessWidget {
  /// 创建 TV 分类筛选行。
  const _TvCategoryFilterRow({
    super.key,
    required this.title,
    required this.options,
    required this.scrollController,
    required this.optionFocusNodeFor,
    this.onArrowUp,
    this.onArrowDown,
    required this.onSelected,
    required this.onFocused,
    required this.isSelected,
  });

  /// 行标题。
  final String title;

  /// 当前行选项。
  final List<TvCategoryFilterOption> options;

  /// 当前行横向滚动控制器。
  final ScrollController scrollController;

  /// 根据筛选项获取稳定焦点节点。
  final FocusNode Function(TvCategoryFilterOption option) optionFocusNodeFor;

  /// 上方向键行级跳转回调。
  final ValueChanged<TvCategoryFilterOption>? onArrowUp;

  /// 下方向键行级跳转回调。
  final ValueChanged<TvCategoryFilterOption>? onArrowDown;

  /// 选中回调。
  final ValueChanged<TvCategoryFilterOption> onSelected;

  /// 获焦回调。
  final ValueChanged<TvCategoryFilterOption> onFocused;

  /// 选中判断。
  final bool Function(TvCategoryFilterOption option) isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '$title:',
              style: FontUtils.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF98A2A8),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('tv-filter-row-scroll-$title'),
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.only(left: 2, right: 12),
              child: Row(
                key: ValueKey('tv-filter-row-$title'),
                children: [
                  for (final entry in options.asMap().entries) ...[
                    if (entry.key > 0) const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final index = entry.key;
                        final option = entry.value;
                        final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
                        final isFirstItem = index == 0;
                        final isLastItem = index == options.length - 1;
                        return TvEdgeShake(
                          key: edgeShakeKey,
                          child: _TvCategoryFilterChip(
                            throttleGroupKey: 'tv-category-filter-row-$title',
                            label: option.label,
                            selected: isSelected(option),
                            focusNode: optionFocusNodeFor(option),
                            onPressed: () => onSelected(option),
                            onFocusChanged: (hasFocus) {
                              if (hasFocus) {
                                onFocused(option);
                              }
                            },
                            onArrowLeft: isFirstItem
                                ? () => edgeShakeKey.currentState
                                    ?.shake(AxisDirection.left)
                                : null,
                            onArrowRight: isLastItem
                                ? () => edgeShakeKey.currentState
                                    ?.shake(AxisDirection.right)
                                : null,
                            onArrowUp: onArrowUp == null
                                ? null
                                : () => onArrowUp!(option),
                            onArrowDown: onArrowDown == null
                                ? null
                                : () => onArrowDown!(option),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TV 分类筛选按钮。
class _TvCategoryFilterChip extends StatelessWidget {
  /// 创建 TV 分类筛选按钮。
  const _TvCategoryFilterChip({
    required this.throttleGroupKey,
    required this.label,
    required this.selected,
    this.focusNode,
    required this.onPressed,
    this.onFocusChanged,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
  });

  /// 当前行共享的方向键长按节流分组。
  final Object throttleGroupKey;

  /// 展示文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 外部焦点节点。
  final FocusNode? focusNode;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 左边界方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右边界方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键行级跳转回调。
  final VoidCallback? onArrowUp;

  /// 下方向键行级跳转回调。
  final VoidCallback? onArrowDown;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      directionalRepeatThrottleGroupKey: throttleGroupKey,
      directionalRepeatThrottleDuration: const Duration(milliseconds: 80),
      focusNode: focusNode,
      onPressed: onPressed,
      onFocusChanged: onFocusChanged,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        // 筛选按钮焦点仅保留描边，避免整体缩放后白边落在半像素上显得左右更粗。
        return AnimatedContainer(
          key: ValueKey('tv-filter-chip-$label'),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minWidth: 38,
            maxWidth: 72,
            minHeight: 30,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? palette.accent : const Color(0xFF343943),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? palette.selectedText : Colors.white,
            ),
          ),
        );
      },
    );
  }
}
