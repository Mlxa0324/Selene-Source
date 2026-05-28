import 'package:flutter/material.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 确认弹框。
///
/// 统一提供大屏场景下的深色确认面板、底部双按钮布局和遥控器焦点行为。
class TvConfirmDialog extends StatefulWidget {
  /// 弹框主体最大宽度。
  ///
  /// 相比首版进一步收紧，避免在大屏上显得过于笨重。
  static const double dialogWidth = 372;

  /// 顶部内容区高度。
  ///
  /// 标题和说明文字都压缩到更紧凑的安全范围内。
  static const double contentHeight = 124;

  /// 底部按钮区高度。
  static const double actionHeight = 58;

  /// 创建 TV 确认弹框。
  const TvConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = '取消',
  });

  /// 弹框标题。
  final String title;

  /// 弹框说明文案。
  final String message;

  /// 右侧确认按钮文案。
  final String confirmLabel;

  /// 左侧取消按钮文案。
  final String cancelLabel;

  @override
  State<TvConfirmDialog> createState() => _TvConfirmDialogState();
}

class _TvConfirmDialogState extends State<TvConfirmDialog> {
  /// 取消按钮焦点节点。
  final FocusNode _cancelFocusNode = FocusNode();

  /// 确认按钮焦点节点。
  final FocusNode _confirmFocusNode = FocusNode();

  @override
  void dispose() {
    _cancelFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  /// 处理弹框返回键。
  ///
  /// 按遥控器返回键或模拟器 `Esc` 时统一按取消处理。
  Future<bool> _handleBackPressed() async {
    if (!mounted) {
      return true;
    }
    Navigator.of(context).pop(false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: TvBackHandler(
        onBackPressed: _handleBackPressed,
        child: Container(
          key: const ValueKey('tv-confirm-dialog'),
          width: TvConfirmDialog.dialogWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF3B3B3D),
            borderRadius: BorderRadius.circular(17),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: TvConfirmDialog.contentHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: FontUtils.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: FontUtils.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFD6D8DD),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: TvConfirmDialog.actionHeight,
                decoration: const BoxDecoration(
                  color: Color(0xFF535355),
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFF666669),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TvConfirmDialogActionButton(
                        buttonKey: const ValueKey('tv-confirm-cancel-button'),
                        focusNode: _cancelFocusNode,
                        autofocus: true,
                        label: widget.cancelLabel,
                        onPressed: () => Navigator.of(context).pop(false),
                        onArrowRight: _confirmFocusNode.requestFocus,
                      ),
                    ),
                    const SizedBox(
                      width: 1,
                      child: ColoredBox(color: Color(0xFF666669)),
                    ),
                    Expanded(
                      child: _TvConfirmDialogActionButton(
                        buttonKey: const ValueKey('tv-confirm-confirm-button'),
                        focusNode: _confirmFocusNode,
                        label: widget.confirmLabel,
                        onPressed: () => Navigator.of(context).pop(true),
                        onArrowLeft: _cancelFocusNode.requestFocus,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TV 确认弹框底部操作按钮。
class _TvConfirmDialogActionButton extends StatelessWidget {
  /// 创建 TV 确认弹框底部操作按钮。
  const _TvConfirmDialogActionButton({
    this.buttonKey,
    required this.focusNode,
    required this.label,
    required this.onPressed,
    this.onArrowLeft,
    this.onArrowRight,
    this.autofocus = false,
  });

  /// 按钮测试定位 Key。
  final Key? buttonKey;

  /// 按钮焦点节点。
  final FocusNode focusNode;

  /// 按钮文案。
  final String label;

  /// 按钮点击回调。
  final VoidCallback onPressed;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 是否默认请求焦点。
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      autoScrollOnFocus: false,
      onPressed: onPressed,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          key: buttonKey,
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          color: hasFocus ? palette.accent : Colors.transparent,
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: hasFocus ? palette.selectedText : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// 展示 TV 风格确认弹框。
Future<bool> showTvConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) {
      return TvTheme.wrapScope(
        context: context,
        child: TvConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        ),
      );
    },
  );
  return result ?? false;
}
