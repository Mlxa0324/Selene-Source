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
  });

  /// 行标题。
  final String title;

  /// 横向筛选项。
  final List<TvCategoryFilterOption> options;
}

/// TV 分类筛选选择回调。
typedef TvCategoryFilterChanged = void Function(
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
    this.mode = TvCategoryFilterPanelMode.expanded,
    this.preferredFocusRowTitle,
    this.onChanged,
  });

  /// 当前分类类型。
  final TvCategoryFilterKind kind;

  /// 当前已确认的筛选项。
  final Map<String, TvCategoryFilterOption> selectedOptions;

  /// 当前面板展示模式。
  final TvCategoryFilterPanelMode mode;

  /// 面板展开后优先回到的筛选行标题。
  ///
  /// 从 Grid 区域回到筛选区时，优先回到更贴近内容区的“年份”行。
  final String? preferredFocusRowTitle;

  /// 筛选变化回调。
  final TvCategoryFilterChanged? onChanged;

  @override
  State<TvCategoryFilterPanel> createState() => _TvCategoryFilterPanelState();
}

class _TvCategoryFilterPanelState extends State<TvCategoryFilterPanel> {
  /// 筛选面板半透黑色遮罩，避免下方海报和选项文字重叠。
  static const Color _panelScrimColor = Color(0xD00B0D0E);

  /// 展开态左右安全留白，保持和 Grid 左边界对齐。
  static const double _horizontalPadding = TvLayout.pageHorizontalPadding;

  /// 展开态顶部留白。
  static const double _expandedTopPadding = 6;

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

  /// 当前面板行数据。
  List<TvCategoryFilterRowData> get _rows =>
      TvCategoryFilterOptions.rowsFor(widget.kind);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectedOptionFocusNodeFor(_preferredFocusRowTitle).requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// 处理筛选项选中。
  void _selectOption(String rowTitle, TvCategoryFilterOption option) {
    _optionFocusNodeFor(rowTitle, option.value).requestFocus();
    widget.onChanged?.call(rowTitle, option);
  }

  /// 判断当前选项是否选中。
  bool _isSelected(String rowTitle, TvCategoryFilterOption option) {
    return _selectedOptionFor(rowTitle).value == option.value;
  }

  /// 获取指定行当前选中的筛选项，未选择时默认取第一项“全部”。
  TvCategoryFilterOption _selectedOptionFor(String rowTitle) {
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
    return row.options.first;
  }

  /// 获取指定筛选项的稳定焦点节点。
  FocusNode _optionFocusNodeFor(String rowTitle, String optionValue) {
    final key = '$rowTitle::$optionValue';
    return _optionFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'tv-filter-$key'),
    );
  }

  /// 获取指定行当前选中项的焦点节点。
  FocusNode _selectedOptionFocusNodeFor(String rowTitle) {
    final option = _selectedOptionFor(rowTitle);
    return _optionFocusNodeFor(rowTitle, option.value);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (widget.mode == TvCategoryFilterPanelMode.compact) {
      return Container(
        key: const ValueKey('tv-category-filter-summary'),
        padding: _compactPadding,
        color: _panelScrimColor,
        child: _TvCategoryFilterCompactSummary(
          rows: rows,
          selectedOptions: widget.selectedOptions,
        ),
      );
    }

    return Container(
      key: const ValueKey('tv-category-filter-panel'),
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        _expandedTopPadding,
        _horizontalPadding,
        _expandedBottomPadding,
      ),
      color: _panelScrimColor,
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
                  title: row.title,
                  options: row.options,
                  optionFocusNodeFor: (option) =>
                      _optionFocusNodeFor(row.title, option.value),
                  onArrowUp: previousRowTitle == null
                      ? null
                      : () => _selectedOptionFocusNodeFor(previousRowTitle)
                          .requestFocus(),
                  onArrowDown: nextRowTitle == null
                      ? null
                      : () => _selectedOptionFocusNodeFor(nextRowTitle)
                          .requestFocus(),
                  onSelected: (option) => _selectOption(row.title, option),
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

  /// 通用排序选项。
  static const List<TvCategoryFilterOption> sortOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '综合', value: 'T'),
    TvCategoryFilterOption(label: '最新', value: 'R'),
    TvCategoryFilterOption(label: '最热', value: 'U'),
    TvCategoryFilterOption(label: '评分', value: 'S'),
  ];

  /// 通用地区选项。
  static const List<TvCategoryFilterOption> regionOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '大陆', value: 'mainland_china'),
    TvCategoryFilterOption(label: '香港', value: 'hong_kong'),
    TvCategoryFilterOption(label: '台湾', value: 'taiwan'),
    TvCategoryFilterOption(label: '美国', value: 'usa'),
    TvCategoryFilterOption(label: '日本', value: 'japanese'),
    TvCategoryFilterOption(label: '韩国', value: 'korean'),
    TvCategoryFilterOption(label: '其它', value: 'other'),
  ];

  /// 通用年份选项。
  static const List<TvCategoryFilterOption> yearOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '2026', value: '2026'),
    TvCategoryFilterOption(label: '2025', value: '2025'),
    TvCategoryFilterOption(label: '2024', value: '2024'),
    TvCategoryFilterOption(label: '2023', value: '2023'),
    TvCategoryFilterOption(label: '2022', value: '2022'),
    TvCategoryFilterOption(label: '2021', value: '2021'),
    TvCategoryFilterOption(label: '2020', value: '2020'),
    TvCategoryFilterOption(label: '10年代', value: '2010s'),
    TvCategoryFilterOption(label: '00年代', value: '2000s'),
    TvCategoryFilterOption(label: '90年代', value: '1990s'),
    TvCategoryFilterOption(label: '80年代', value: '1980s'),
    TvCategoryFilterOption(label: '更早', value: 'earlier'),
  ];

  /// 电影类型选项。
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
  ];

  /// 剧集类型选项。
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
    TvCategoryFilterOption(label: '历史', value: 'history'),
    TvCategoryFilterOption(label: '剧情', value: 'drama'),
  ];

  /// 动漫类型选项。
  static const List<TvCategoryFilterOption> animeTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '番剧', value: 'series'),
    TvCategoryFilterOption(label: '剧场版', value: 'movie'),
    TvCategoryFilterOption(label: '国漫', value: 'chinese_anime'),
    TvCategoryFilterOption(label: '恋爱', value: 'love'),
    TvCategoryFilterOption(label: '治愈', value: 'healing'),
    TvCategoryFilterOption(label: '运动', value: 'sports'),
    TvCategoryFilterOption(label: '悬疑', value: 'suspense'),
    TvCategoryFilterOption(label: '科幻', value: 'sci_fi'),
    TvCategoryFilterOption(label: '魔幻', value: 'fantasy'),
  ];

  /// 综艺类型选项。
  static const List<TvCategoryFilterOption> varietyTypeOptions = [
    TvCategoryFilterOption(label: '全部', value: 'all'),
    TvCategoryFilterOption(label: '真人秀', value: 'reality'),
    TvCategoryFilterOption(label: '脱口秀', value: 'talkshow'),
    TvCategoryFilterOption(label: '音乐', value: 'music'),
    TvCategoryFilterOption(label: '歌舞', value: 'musical'),
    TvCategoryFilterOption(label: '喜剧', value: 'comedy'),
    TvCategoryFilterOption(label: '冒险', value: 'adventure'),
    TvCategoryFilterOption(label: '运动', value: 'sports'),
  ];

  /// 根据分类返回筛选行。
  static List<TvCategoryFilterRowData> rowsFor(TvCategoryFilterKind kind) {
    return [
      const TvCategoryFilterRowData(title: '排序', options: sortOptions),
      TvCategoryFilterRowData(title: '类型', options: _typeOptionsFor(kind)),
      const TvCategoryFilterRowData(title: '地区', options: regionOptions),
      const TvCategoryFilterRowData(title: '年份', options: yearOptions),
    ];
  }

  /// 根据分类返回类型选项。
  static List<TvCategoryFilterOption> _typeOptionsFor(
    TvCategoryFilterKind kind,
  ) {
    switch (kind) {
      case TvCategoryFilterKind.movie:
        return movieTypeOptions;
      case TvCategoryFilterKind.series:
        return seriesTypeOptions;
      case TvCategoryFilterKind.anime:
        return animeTypeOptions;
      case TvCategoryFilterKind.variety:
        return varietyTypeOptions;
    }
  }
}

/// TV 分类筛选行。
class _TvCategoryFilterRow extends StatelessWidget {
  /// 创建 TV 分类筛选行。
  const _TvCategoryFilterRow({
    required this.title,
    required this.options,
    required this.optionFocusNodeFor,
    this.onArrowUp,
    this.onArrowDown,
    required this.onSelected,
    required this.isSelected,
  });

  /// 行标题。
  final String title;

  /// 当前行选项。
  final List<TvCategoryFilterOption> options;

  /// 根据筛选项获取稳定焦点节点。
  final FocusNode Function(TvCategoryFilterOption option) optionFocusNodeFor;

  /// 上方向键行级跳转回调。
  final VoidCallback? onArrowUp;

  /// 下方向键行级跳转回调。
  final VoidCallback? onArrowDown;

  /// 选中回调。
  final ValueChanged<TvCategoryFilterOption> onSelected;

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
            child: ListView.separated(
              key: ValueKey('tv-filter-row-$title'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.only(left: 2, right: 0),
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final option = options[index];
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
                    onArrowLeft: isFirstItem
                        ? () =>
                            edgeShakeKey.currentState?.shake(AxisDirection.left)
                        : null,
                    onArrowRight: isLastItem
                        ? () => edgeShakeKey.currentState
                            ?.shake(AxisDirection.right)
                        : null,
                    onArrowUp: onArrowUp,
                    onArrowDown: onArrowDown,
                  ),
                );
              },
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
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        return AnimatedScale(
          scale: hasFocus ? 1.06 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            key: ValueKey('tv-filter-chip-$label'),
            duration: const Duration(milliseconds: 140),
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
          ),
        );
      },
    );
  }
}
