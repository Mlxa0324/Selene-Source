import 'package:flutter/material.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 标题与右侧提示组合组件。
///
/// 用于统一首页横向分区和分类页标题区的提示字号与纵向对齐位置。
class TvSectionTitle extends StatelessWidget {
  /// 创建 TV 标题与右侧提示组合组件。
  ///
  /// [title] 为主标题文案。
  /// [titleHint] 为标题右侧弱提示文案。
  const TvSectionTitle({
    super.key,
    required this.title,
    this.titleHint,
    this.titleHintKey,
    this.mainAxisSize = MainAxisSize.min,
    this.flexibleHint = false,
    this.hintOverflow = TextOverflow.visible,
  });

  /// 标题文案。
  final String title;

  /// 标题右侧弱提示文案。
  final String? titleHint;

  /// 提示文案节点 Key。
  final Key? titleHintKey;

  /// 标题行主轴尺寸策略。
  final MainAxisSize mainAxisSize;

  /// 是否让提示文案在可用宽度内弹性收缩。
  ///
  /// 分类页标题右侧可能跟着更长的提示，需要启用弹性布局避免溢出。
  final bool flexibleHint;

  /// 提示文案溢出策略。
  final TextOverflow hintOverflow;

  /// 主标题字号。
  static const double titleFontSize = 28;

  /// 提示文案字号。
  ///
  /// 沿用分类页既有提示大小，避免继续观看提示显得偏小。
  static const double hintFontSize = 16;

  /// 标题与提示之间的横向间距。
  static const double hintSpacing = 14;

  /// 提示文案底部微调。
  ///
  /// 让分类页提示沿用“继续观看”右侧小字的上下位置。
  static const double hintBottomPadding = 3;

  /// 提示文案最大行数。
  static const int hintMaxLines = 1;

  /// 提示文案颜色。
  static const Color hintColor = Color(0xFF7F8A8F);

  @override
  Widget build(BuildContext context) {
    final hint = titleHint;
    Widget? hintWidget;
    if (hint?.isNotEmpty == true) {
      final textWidget = Padding(
        padding: const EdgeInsets.only(bottom: hintBottomPadding),
        child: Text(
          hint!,
          key: titleHintKey,
          maxLines: hintMaxLines,
          overflow: hintOverflow,
          style: FontUtils.poppins(
            fontSize: hintFontSize,
            fontWeight: FontWeight.w500,
            color: hintColor,
          ),
        ),
      );
      hintWidget = flexibleHint ? Flexible(child: textWidget) : textWidget;
    }

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: FontUtils.poppins(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (hintWidget != null) ...[
          const SizedBox(width: hintSpacing),
          hintWidget,
        ],
      ],
    );
  }
}
