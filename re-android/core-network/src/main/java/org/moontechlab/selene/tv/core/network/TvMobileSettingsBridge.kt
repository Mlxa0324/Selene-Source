package org.moontechlab.selene.tv.core.network

import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Collections
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * TV 手机端配置草稿。
 *
 * 对齐 Flutter `TvMobileSettingsDraft`，承载适合手机录入的核心字段。
 *
 * @property serverUrl 服务器地址。
 * @property username 登录账号。
 * @property password 登录密码。
 * @property doubanImageSource 图片代理显示名。
 * @property adFilterEnabled 是否开启自动去广告。
 * @property danmakuBaseApi 弹幕服务器地址。
 */
data class TvMobileSettingsDraft(
    val serverUrl: String = "",
    val username: String = "",
    val password: String = "",
    val doubanImageSource: String = DEFAULT_IMAGE_SOURCE,
    val adFilterEnabled: Boolean = true,
    val danmakuBaseApi: String = "",
) {
    companion object {
        /** 与 Flutter 一致的图片代理可选项。 */
        val availableDoubanImageSources: List<String> = listOf(
            "豆瓣官方精品 CDN",
            "直连",
            "豆瓣 CDN By CMLiussss（腾讯云）",
            "豆瓣 CDN By CMLiussss（阿里云）",
        )

        /** 默认图片代理。 */
        const val DEFAULT_IMAGE_SOURCE: String = "豆瓣官方精品 CDN"

        /**
         * 根据手机网页提交字段重建草稿。
         *
         * @param fields 表单字段。
         * @return 规整后的草稿。
         */
        fun fromFormFields(fields: Map<String, String>): TvMobileSettingsDraft {
            val imageSource = fields["doubanImageSource"]?.trim().orEmpty()
            return TvMobileSettingsDraft(
                serverUrl = fields["serverUrl"]?.trim().orEmpty(),
                username = fields["username"]?.trim().orEmpty(),
                password = fields["password"].orEmpty(),
                doubanImageSource = if (imageSource in availableDoubanImageSources) {
                    imageSource
                } else {
                    DEFAULT_IMAGE_SOURCE
                },
                adFilterEnabled = parseBool(fields["adFilterEnabled"]),
                danmakuBaseApi = fields["danmakuBaseApi"]?.trim().orEmpty(),
            )
        }

        /**
         * 解析表单布尔值。
         *
         * @param rawValue 原始字段。
         * @return 是否开启。
         */
        private fun parseBool(rawValue: String?): Boolean {
            val normalized = rawValue?.trim()?.lowercase().orEmpty()
            return normalized == "true" || normalized == "1" || normalized == "on"
        }
    }
}

/**
 * 手机扫码配置桥接会话。
 *
 * @property shareUri 手机可访问地址；局域网不可用时为 null。
 * @property statusText 当前状态文案。
 * @property updateDraft 同步 TV 端当前草稿到手机网页。
 * @property dispose 关闭本地服务并释放资源。
 */
data class TvMobileSettingsBridgeSession(
    val shareUri: String?,
    val statusText: String,
    val updateDraft: (TvMobileSettingsDraft) -> Unit,
    val dispose: suspend () -> Unit,
)

/**
 * TV 手机配置桥接服务。
 *
 * 在局域网启动轻量 HTTP 服务，手机扫码后填写配置并回传给电视。
 */
object TvMobileSettingsBridge {
    // FORCE_REBUILD_MARKER
    /** 手机扫码配置起始端口。 */
    const val INITIAL_SHARE_PORT: Int = 18321

    /** 手机网页可用时的默认提示。 */
    const val READY_STATUS: String = "请使用与电视同一局域网的手机扫码填写配置"

    /** 手机配置已提交后的提示。 */
    const val APPLIED_STATUS: String = "已从手机接收配置，返回电视后确认保存即可"

    /** 局域网地址不可用时的提示。 */
    const val UNAVAILABLE_STATUS: String = "未获取到局域网地址，请检查电视网络连接"

    /** 当前 App 生命周期内缓存的分享主机。 */
    @Volatile
    private var cachedShareHost: String? = null

    /** 下一个优先尝试的分享端口。 */
    @Volatile
    private var nextPreferredPort: Int = INITIAL_SHARE_PORT

    /**
     * 启动一个新的手机配置桥接会话。
     *
     * @param initialDraft 初始草稿。
     * @param onDraftSubmitted 手机提交后回调到 TV。
     * @param preferredHost 优先使用的主机地址。
     * @param allocateNewPort 是否强制换新端口（重新生成二维码时使用）。
     * @return 可观察分享地址与状态的会话。
     */
    suspend fun startSession(
        initialDraft: TvMobileSettingsDraft,
        onDraftSubmitted: (TvMobileSettingsDraft) -> Unit,
        preferredHost: String? = null,
        allocateNewPort: Boolean = false,
    ): TvMobileSettingsBridgeSession = withContext(Dispatchers.IO) {
        val shareHost = resolveShareHost(preferredHost)
        if (shareHost.isNullOrBlank()) {
            return@withContext TvMobileSettingsBridgeSession(
                shareUri = null,
                statusText = UNAVAILABLE_STATUS,
                updateDraft = {},
                dispose = {},
            )
        }

        val serverSocket = bindShareServer(allocateNewPort = allocateNewPort)
        val runner = RunningBridge(
            serverSocket = serverSocket,
            shareHost = shareHost,
            initialDraft = initialDraft,
            onDraftSubmitted = onDraftSubmitted,
        )
        runner.start()
        TvMobileSettingsBridgeSession(
            shareUri = "http://$shareHost:${serverSocket.localPort}",
            statusText = READY_STATUS,
            updateDraft = runner::updateDraft,
            dispose = {
                withContext(Dispatchers.IO) {
                    runner.dispose()
                }
            },
        )
    }

    /**
     * 绑定扫码配置服务端口。
     *
     * @param allocateNewPort 是否从下一端口开始尝试。
     * @return 已绑定的服务端 Socket。
     */
    private fun bindShareServer(allocateNewPort: Boolean): ServerSocket {
        var candidatePort = if (allocateNewPort) nextPreferredPort + 1 else nextPreferredPort
        while (true) {
            try {
                val server = ServerSocket(candidatePort)
                nextPreferredPort = server.localPort
                return server
            } catch (_: SocketException) {
                candidatePort++
            }
        }
    }

    /**
     * 解析当前设备对手机可见的局域网地址。
     *
     * @param preferredHost 优先主机。
     * @return IPv4 主机地址；找不到时返回 null。
     */
    private fun resolveShareHost(preferredHost: String?): String? {
        val normalizedPreferredHost = preferredHost?.trim().orEmpty()
        if (normalizedPreferredHost.isNotEmpty()) {
            cachedShareHost = normalizedPreferredHost
            return normalizedPreferredHost
        }

        val cached = cachedShareHost
        if (!cached.isNullOrBlank()) {
            return cached
        }

        val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
        // 优先选择常见私有 IPv4，避免把不可达地址暴露给手机。
        for (networkInterface in interfaces) {
            for (address in Collections.list(networkInterface.inetAddresses)) {
                if (address is Inet4Address && !address.isLoopbackAddress && isPrivateIpv4(address.hostAddress)) {
                    cachedShareHost = address.hostAddress
                    return cachedShareHost
                }
            }
        }
        for (networkInterface in interfaces) {
            for (address in Collections.list(networkInterface.inetAddresses)) {
                if (address is Inet4Address && !address.isLoopbackAddress) {
                    cachedShareHost = address.hostAddress
                    return cachedShareHost
                }
            }
        }
        return null
    }

    /**
     * 判断是否属于常见私有 IPv4 地址段。
     *
     * @param address IP 文本。
     * @return 是否私有地址。
     */
    private fun isPrivateIpv4(address: String?): Boolean {
        if (address.isNullOrBlank()) return false
        val octets = address.split('.')
        if (octets.size != 4) return false
        val first = octets[0].toIntOrNull() ?: return false
        val second = octets[1].toIntOrNull() ?: return false
        return when (first) {
            10 -> true
            172 -> second in 16..31
            192 -> second == 168
            else -> false
        }
    }

    /**
     * 运行中的轻量 HTTP 服务。
     *
     * @property serverSocket 已绑定端口。
     * @property shareHost 对外主机。
     * @property initialDraft 初始草稿。
     * @property onDraftSubmitted 手机提交回调。
     */
    private class RunningBridge(
        private val serverSocket: ServerSocket,
        private val shareHost: String,
        initialDraft: TvMobileSettingsDraft,
        private val onDraftSubmitted: (TvMobileSettingsDraft) -> Unit,
    ) {
        /** 是否仍在接受连接。 */
        private val running = AtomicBoolean(true)

        /** 当前草稿快照。 */
        private val draftRef = AtomicReference(initialDraft)

        /** 最新状态文案。 */
        private val statusRef = AtomicReference(READY_STATUS)

        /** 接收线程池。 */
        private val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "tv-mobile-settings-bridge").apply { isDaemon = true }
        }

        /**
         * 启动接收循环。
         */
        fun start() {
            executor.execute {
                while (running.get()) {
                    try {
                        val client = serverSocket.accept()
                        handleClient(client)
                    } catch (_: Exception) {
                        if (!running.get()) break
                    }
                }
            }
        }

        /**
         * 同步 TV 端当前草稿。
         *
         * @param draft 新草稿。
         */
        fun updateDraft(draft: TvMobileSettingsDraft) {
            draftRef.set(draft)
        }

        /**
         * 关闭服务。
         */
        fun dispose() {
            running.set(false)
            runCatching { serverSocket.close() }
            executor.shutdownNow()
        }

        /**
         * 处理单个 HTTP 连接。
         *
         * @param socket 客户端连接。
         */
        private fun handleClient(socket: Socket) {
            socket.use { client ->
                val reader = BufferedReader(InputStreamReader(client.getInputStream(), StandardCharsets.UTF_8))
                val requestLine = reader.readLine() ?: return
                val parts = requestLine.split(' ')
                if (parts.size < 2) {
                    writeResponse(client, 400, "text/plain; charset=utf-8", "Bad Request")
                    return
                }
                val method = parts[0].uppercase()
                val path = parts[1].substringBefore('?')

                // 读完请求头，必要时拿 Content-Length 解析 body。
                var contentLength = 0
                while (true) {
                    val header = reader.readLine() ?: break
                    if (header.isEmpty()) break
                    val lower = header.lowercase()
                    if (lower.startsWith("content-length:")) {
                        contentLength = lower.substringAfter(':').trim().toIntOrNull() ?: 0
                    }
                }

                when {
                    method == "GET" && (path == "/" || path == "/index.html") -> {
                        val html = buildHtmlPage(
                            draft = draftRef.get(),
                            actionPath = "/",
                            successMessage = null,
                        )
                        writeResponse(client, 200, "text/html; charset=utf-8", html)
                    }

                    method == "POST" && path == "/" -> {
                        val body = readBody(reader, contentLength)
                        val fields = parseFormBody(body)
                        val draft = TvMobileSettingsDraft.fromFormFields(fields)
                        draftRef.set(draft)
                        statusRef.set(APPLIED_STATUS)
                        // 提交后回写 TV 表单，用户回到电视再确认保存。
                        onDraftSubmitted(draft)
                        val html = buildHtmlPage(
                            draft = draft,
                            actionPath = "/",
                            successMessage = "配置已同步到电视，请返回电视确认保存。",
                        )
                        writeResponse(client, 200, "text/html; charset=utf-8", html)
                    }

                    else -> {
                        writeResponse(
                            client,
                            404,
                            "text/html; charset=utf-8",
                            "<html><body><h1>404</h1><p>配置页面不存在。</p></body></html>",
                        )
                    }
                }
            }
        }

        /**
         * 读取请求体。
         *
         * @param reader 请求流。
         * @param contentLength 体长度。
         * @return 原始 body 文本。
         */
        private fun readBody(reader: BufferedReader, contentLength: Int): String {
            if (contentLength <= 0) return ""
            val chars = CharArray(contentLength)
            var offset = 0
            while (offset < contentLength) {
                val read = reader.read(chars, offset, contentLength - offset)
                if (read < 0) break
                offset += read
            }
            return String(chars, 0, offset)
        }

        /**
         * 解析 application/x-www-form-urlencoded 表单。
         *
         * @param body 原始 body。
         * @return 字段映射。
         */
        private fun parseFormBody(body: String): Map<String, String> {
            if (body.isBlank()) return emptyMap()
            return body.split('&')
                .mapNotNull { pair ->
                    if (pair.isBlank()) return@mapNotNull null
                    val key = pair.substringBefore('=', missingDelimiterValue = pair)
                    val value = pair.substringAfter('=', missingDelimiterValue = "")
                    urlDecode(key) to urlDecode(value)
                }
                .toMap()
        }

        /**
         * URL 解码。
         *
         * @param value 原始片段。
         * @return 解码文本。
         */
        private fun urlDecode(value: String): String {
            return URLDecoder.decode(value.replace('+', ' '), StandardCharsets.UTF_8.name())
        }

        /**
         * 写出 HTTP 响应。
         *
         * @param socket 客户端。
         * @param status 状态码。
         * @param contentType Content-Type。
         * @param body 响应体。
         */
        private fun writeResponse(
            socket: Socket,
            status: Int,
            contentType: String,
            body: String,
        ) {
            val bytes = body.toByteArray(StandardCharsets.UTF_8)
            val reason = when (status) {
                200 -> "OK"
                400 -> "Bad Request"
                404 -> "Not Found"
                else -> "OK"
            }
            OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8).use { writer ->
                writer.write("HTTP/1.1 $status $reason\r\n")
                writer.write("Content-Type: $contentType\r\n")
                writer.write("Content-Length: ${bytes.size}\r\n")
                writer.write("Connection: close\r\n")
                writer.write("\r\n")
                writer.flush()
            }
            socket.getOutputStream().write(bytes)
            socket.getOutputStream().flush()
        }

        /**
         * 构建手机端配置网页。
         *
         * @param draft 当前草稿。
         * @param actionPath 表单 action。
         * @param successMessage 成功提示。
         * @return HTML 文本。
         */
        private fun buildHtmlPage(
            draft: TvMobileSettingsDraft,
            actionPath: String,
            successMessage: String?,
        ): String {
            val imageSourceOptions = TvMobileSettingsDraft.availableDoubanImageSources.joinToString("") { option ->
                val selected = if (option == draft.doubanImageSource) "selected" else ""
                "<option value=\"${escapeHtml(option)}\" $selected>${escapeHtml(option)}</option>"
            }
            val adFilterChecked = if (draft.adFilterEnabled) "checked" else ""
            val successBlock = if (successMessage == null) {
                ""
            } else {
                "<div class=\"success\">${escapeHtml(successMessage)}</div>"
            }
            return """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Selene TV 手机配置</title>
  <style>
    body { margin:0; background:#0f1417; color:#e7f1ee; font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Segoe UI",sans-serif; }
    .shell { max-width:720px; margin:0 auto; padding:24px 18px 48px; }
    .card { background:#151b1f; border:1px solid #263036; border-radius:18px; padding:20px; box-shadow:0 18px 42px rgba(0,0,0,.26); }
    h1 { margin:0 0 8px; font-size:24px; }
    p { margin:0 0 16px; color:#96a3aa; line-height:1.6; }
    .success { margin:0 0 16px; padding:12px 14px; border-radius:12px; background:rgba(92,181,131,.14); color:#9fe2b6; }
    label { display:block; margin:18px 0 8px; font-size:14px; color:#b9c7c3; }
    input, select { width:100%; box-sizing:border-box; border:1px solid #334148; border-radius:12px; background:#0f1417; color:#fff; padding:14px 16px; font-size:16px; }
    .toggle { display:flex; align-items:center; gap:10px; margin-top:18px; color:#d7e3df; }
    button { width:100%; margin-top:24px; border:none; border-radius:14px; background:#5cb583; color:#08110d; padding:16px; font-size:17px; font-weight:700; }
    .meta { margin-top:18px; font-size:13px; color:#708087; }
  </style>
</head>
<body>
  <div class="shell">
    <div class="card">
      <h1>Selene TV 手机配置</h1>
      <p>在手机里填好服务器、图片代理和弹幕地址后提交，电视会自动回填表单，最后回到电视确认保存即可。</p>
      $successBlock
      <form method="post" action="$actionPath">
        <label for="serverUrl">服务器地址</label>
        <input id="serverUrl" name="serverUrl" value="${escapeHtml(draft.serverUrl)}" placeholder="https://example.com" />
        <label for="username">账号</label>
        <input id="username" name="username" value="${escapeHtml(draft.username)}" placeholder="请输入账号" />
        <label for="password">密码</label>
        <input id="password" name="password" type="password" value="${escapeHtml(draft.password)}" placeholder="请输入密码" />
        <label for="doubanImageSource">图片代理</label>
        <select id="doubanImageSource" name="doubanImageSource">$imageSourceOptions</select>
        <label for="danmakuBaseApi">弹幕服务器地址</label>
        <input id="danmakuBaseApi" name="danmakuBaseApi" value="${escapeHtml(draft.danmakuBaseApi)}" placeholder="https://danmaku.example.com/" />
        <label class="toggle" for="adFilterEnabled">
          <input id="adFilterEnabled" name="adFilterEnabled" type="checkbox" value="true" $adFilterChecked style="width:18px;height:18px;" />
          自动去广告
        </label>
        <button type="submit">同步到电视</button>
      </form>
      <div class="meta">当前电视地址：$shareHost:${serverSocket.localPort}</div>
    </div>
  </div>
</body>
</html>
""".trimIndent()
        }

        /**
         * 简单转义 HTML 特殊字符。
         *
         * @param rawValue 原始文本。
         * @return 转义后文本。
         */
        private fun escapeHtml(rawValue: String): String {
            return rawValue
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;")
        }
    }
}
