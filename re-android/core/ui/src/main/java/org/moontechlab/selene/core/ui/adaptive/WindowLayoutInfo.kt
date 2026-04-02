package org.moontechlab.selene.core.ui.adaptive

enum class WindowWidthClass {
    Compact,
    Medium,
    Expanded,
}

data class WindowLayoutInfo(
    val widthClass: WindowWidthClass,
    val isTablet: Boolean,
)
