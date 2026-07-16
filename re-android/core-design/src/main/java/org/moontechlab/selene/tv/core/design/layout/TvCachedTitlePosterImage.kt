package org.moontechlab.selene.tv.core.design.layout

import android.util.Log
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import coil.compose.AsyncImagePainter
import coil.request.ImageRequest

/**
 * 带片名精确匹配回退的封面图。
 *
 * 优先加载 [posterUrl]；失败或为空时，用同名片名在会话内成功加载过的 URL 回退。
 * Coil 会按 URL 命中磁盘/内存缓存，回退时通常直接出图。
 *
 * @param title 影片名（精准匹配键）。
 * @param posterUrl 接口下发的封面地址。
 * @param contentDescription 无障碍描述。
 * @param modifier 外层修饰器。
 * @param contentScale 缩放模式。
 * @param alignment 对齐方式。
 */
@Composable
fun TvCachedTitlePosterImage(
    title: String,
    posterUrl: String,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    alignment: Alignment = Alignment.Center,
) {
    val context = LocalContext.current
    val imageSourceKey = LocalTvImageSourceKey.current
    val primaryUrl = remember(title, posterUrl, imageSourceKey) {
        val resolved = TvPosterTitleUrlCache.resolvePrimaryUrl(title = title, posterUrl = posterUrl)
        resolved?.let { resolveDoubanImageUrl(it, imageSourceKey) }
    }
    var activeUrl by remember(title, posterUrl, imageSourceKey) {
        mutableStateOf(primaryUrl)
    }
    var fallbackTried by remember(title, posterUrl, imageSourceKey) {
        mutableStateOf(false)
    }
    val requestUrl = activeUrl
    if (requestUrl.isNullOrBlank()) {
        return
    }
    val imageRequest = remember(requestUrl, title) {
        ImageRequest.Builder(context)
            .data(requestUrl)
            .crossfade(true)
            .listener(
                onSuccess = { _, _ ->
                    TvPosterTitleUrlCache.putSuccess(title = title, posterUrl = requestUrl)
                },
            )
            .build()
    }
    AsyncImage(
        model = imageRequest,
        contentDescription = contentDescription,
        contentScale = contentScale,
        alignment = alignment,
        modifier = modifier,
        onState = { state ->
            if (state is AsyncImagePainter.State.Error && !fallbackTried) {
                val fallback = TvPosterTitleUrlCache.resolveFallbackUrl(
                    title = title,
                    failedUrl = requestUrl,
                )?.let { resolveDoubanImageUrl(it, imageSourceKey) }
                if (fallback != null) {
                    fallbackTried = true
                    activeUrl = fallback
                    Log.d(
                        "SeleneTV",
                        "封面回退同名缓存: title=$title, fallback=$fallback",
                    )
                }
            }
        },
    )
}
