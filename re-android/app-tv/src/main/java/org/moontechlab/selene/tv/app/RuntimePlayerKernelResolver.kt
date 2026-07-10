package org.moontechlab.selene.tv.app

import android.os.Build

/**
 * 运行时设备信息快照。
 *
 * @property fingerprint 系统指纹。
 * @property model 设备型号。
 * @property manufacturer 设备厂商。
 * @property brand 设备品牌。
 * @property device 设备代号。
 * @property hardware 硬件代号。
 * @property product 产品代号。
 * @property board 主板代号。
 * @property eglHardware EGL 硬件实现标识。
 * @property bootQemu 启动期 QEMU 标识。
 * @property kernelQemu 内核 QEMU 标识。
 * @property blueStacksImeListenerPort BlueStacks 暴露的输入法监听端口。
 */
data class TvPlaybackDeviceInfo(
    val fingerprint: String = "",
    val model: String = "",
    val manufacturer: String = "",
    val brand: String = "",
    val device: String = "",
    val hardware: String = "",
    val product: String = "",
    val board: String = "",
    val eglHardware: String = "",
    val bootQemu: String = "",
    val kernelQemu: String = "",
    val blueStacksImeListenerPort: String = "",
) {
    companion object {
        /**
         * 从当前进程读取设备信息。
         *
         * JVM 单测环境里 Android stub 可能抛异常，这里统一兜底为空串，
         * 避免本地单测因为静态 Build 读取直接崩掉。
         *
         * @return 当前设备信息。
         */
        fun current(): TvPlaybackDeviceInfo {
            return TvPlaybackDeviceInfo(
                fingerprint = readBuildField { Build.FINGERPRINT },
                model = readBuildField { Build.MODEL },
                manufacturer = readBuildField { Build.MANUFACTURER },
                brand = readBuildField { Build.BRAND },
                device = readBuildField { Build.DEVICE },
                hardware = readBuildField { Build.HARDWARE },
                product = readBuildField { Build.PRODUCT },
                board = readBuildField { Build.BOARD },
                eglHardware = readSystemProperty("ro.hardware.egl"),
                bootQemu = readSystemProperty("ro.boot.qemu"),
                kernelQemu = readSystemProperty("ro.kernel.qemu"),
                blueStacksImeListenerPort = readSystemProperty("ro.bst.ime_listener_port"),
            )
        }

        /**
         * 安全读取单个 Build 字段。
         *
         * @param reader 字段读取逻辑。
         * @return 字段值；异常时回空串。
         */
        private fun readBuildField(reader: () -> String?): String {
            return runCatching { reader().orEmpty() }
                .getOrDefault("")
        }

        /**
         * 安全读取 Android system property。
         *
         * @param key 属性键。
         * @return 属性值；异常时回空串。
         */
        private fun readSystemProperty(key: String): String {
            return runCatching {
                val systemPropertiesClass = Class.forName("android.os.SystemProperties")
                val getMethod = systemPropertiesClass.getMethod("get", String::class.java)
                (getMethod.invoke(null, key) as? String).orEmpty()
            }.getOrDefault("")
        }
    }
}

/**
 * 运行时播放器内核决策结果。
 *
 * @property preferredKernel 用户偏好内核。
 * @property effectiveKernel 当前真实生效内核。
 * @property fallbackReason 命中自动回退时的原因标识。
 */
data class RuntimePlayerKernelDecision(
    val preferredKernel: String,
    val effectiveKernel: String,
    val fallbackReason: String? = null,
)

/**
 * 解析当前环境下真正应该启用的播放器内核。
 *
 * WebView 仍然是常规环境默认首选，但模拟器 / BlueStacks 这类平台视图合成高风险环境下，
 * 会自动回退到 Exo，优先保证详情页和全屏播放器稳定出画。
 *
 * @property deviceInfo 当前设备信息。
 */
class RuntimePlayerKernelResolver(
    private val deviceInfo: TvPlaybackDeviceInfo = TvPlaybackDeviceInfo.current(),
) {
    /**
     * 计算当前偏好对应的真实运行内核。
     *
     * @param preferredKernel 用户保存的播放器偏好。
     * @return 当前环境下的真实内核决策。
     */
    fun resolve(preferredKernel: String): RuntimePlayerKernelDecision {
        val normalizedPreferredKernel = normalizeKernel(preferredKernel)
        val fallbackReason = when {
            normalizedPreferredKernel != PLAYER_KERNEL_WEBVIEW -> null
            isBlueStacksRuntime() -> BLUESTACKS_FALLBACK_REASON
            isAndroidEmulatorRuntime() -> EMULATOR_FALLBACK_REASON
            else -> null
        }
        val effectiveKernel = if (fallbackReason == null) {
            normalizedPreferredKernel
        } else {
            PLAYER_KERNEL_EXO
        }

        return RuntimePlayerKernelDecision(
            preferredKernel = normalizedPreferredKernel,
            effectiveKernel = effectiveKernel,
            fallbackReason = fallbackReason,
        )
    }

    /**
     * 判断当前是否属于 Android Emulator 风险环境。
     *
     * @return `true` 表示 WebView 视频层命中高风险环境。
     */
    private fun isAndroidEmulatorRuntime(): Boolean {
        val fingerprint = deviceInfo.fingerprint.lowercase()
        val model = deviceInfo.model.lowercase()
        val brand = deviceInfo.brand.lowercase()
        val device = deviceInfo.device.lowercase()
        val hardware = deviceInfo.hardware.lowercase()
        val product = deviceInfo.product.lowercase()
        val eglHardware = deviceInfo.eglHardware.lowercase()
        val bootQemu = deviceInfo.bootQemu
        val kernelQemu = deviceInfo.kernelQemu

        return bootQemu == "1" ||
            kernelQemu == "1" ||
            eglHardware.contains("emulation") ||
            fingerprint.startsWith("generic") ||
            fingerprint.startsWith("unknown") ||
            model.contains("google_sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk built for x86") ||
            model.contains("sdk_gphone") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu") ||
            (brand.startsWith("generic") && device.startsWith("generic")) ||
            product.contains("sdk_gphone") ||
            product.contains("emulator") ||
            product.contains("simulator")
    }

    /**
     * 判断当前是否属于 BlueStacks 风险环境。
     *
     * @return `true` 表示需要直接跳过 WebView 画面链路。
     */
    private fun isBlueStacksRuntime(): Boolean {
        if (deviceInfo.blueStacksImeListenerPort.isNotBlank()) {
            return true
        }

        return listOf(
            deviceInfo.fingerprint,
            deviceInfo.model,
            deviceInfo.manufacturer,
            deviceInfo.brand,
            deviceInfo.device,
            deviceInfo.hardware,
            deviceInfo.product,
            deviceInfo.board,
        ).any { field ->
            field.lowercase().contains("bluestacks")
        }
    }

    /**
     * 规整传入的内核标识。
     *
     * @param kernel 原始内核值。
     * @return 受支持的内核标识。
     */
    private fun normalizeKernel(kernel: String?): String {
        return when (kernel?.trim()?.lowercase()) {
            PLAYER_KERNEL_EXO -> PLAYER_KERNEL_EXO
            PLAYER_KERNEL_WEBVIEW -> PLAYER_KERNEL_WEBVIEW
            else -> PLAYER_KERNEL_WEBVIEW
        }
    }

    companion object {
        /** ExoPlayer 内核标识。 */
        const val PLAYER_KERNEL_EXO: String = "exo"

        /** WebView 内核标识。 */
        const val PLAYER_KERNEL_WEBVIEW: String = "webview"

        /** 模拟器环境自动回退原因。 */
        const val EMULATOR_FALLBACK_REASON: String = "emulator_webview_black_screen"

        /** BlueStacks 环境自动回退原因。 */
        const val BLUESTACKS_FALLBACK_REASON: String = "bluestacks_webview_black_screen"
    }
}
