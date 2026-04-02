package org.moontechlab.selene.core.ui.adaptive

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration

@Composable
fun rememberWindowLayoutInfo(): WindowLayoutInfo {
    val configuration = LocalConfiguration.current
    val widthDp = configuration.screenWidthDp
    val widthClass = when {
        widthDp >= 840 -> WindowWidthClass.Expanded
        widthDp >= 600 -> WindowWidthClass.Medium
        else -> WindowWidthClass.Compact
    }

    return remember(widthDp) {
        WindowLayoutInfo(
            widthClass = widthClass,
            isTablet = widthDp >= 600,
        )
    }
}
