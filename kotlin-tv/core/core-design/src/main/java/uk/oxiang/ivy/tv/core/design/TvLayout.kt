package uk.oxiang.ivy.tv.core.design

/**
 * TV 端页面布局常量。
 *
 * 统一管理大屏页面的左右安全边距和纵向 Grid 列数，对齐 Flutter `lib/tv_app/tv_layout.dart`。
 */
object TvLayout {
    /**
     * TV 页面左右统一边距。
     *
     * 横向列表可在此基础上追加焦点安全留白，避免获焦放大时被裁切。
     */
    const val pageHorizontalPadding = 46

    /**
     * TV 纵向 Grid 固定列数。
     */
    const val gridCrossAxisCount = 7
}
