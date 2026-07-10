package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验运行时播放器内核解析契约。
 */
class RuntimePlayerKernelResolverTest {
    /**
     * Android Emulator 的 WebView 视频层已知容易出现有声黑屏，
     * 默认 WebView 偏好必须自动回退到 Exo。
     */
    @Test
    fun resolve_falls_back_to_exo_for_webview_on_android_emulator() {
        val resolver = RuntimePlayerKernelResolver(
            deviceInfo = TvPlaybackDeviceInfo(
                fingerprint = "google/sdk_gphone64_arm64/generic:14/UP1A/test-keys",
                model = "sdk_gphone64_arm64",
                brand = "google",
                device = "emu64a",
                hardware = "ranchu",
                product = "sdk_gphone64_arm64",
            ),
        )

        val decision = resolver.resolve("webview")

        assertThat(decision.preferredKernel).isEqualTo("webview")
        assertThat(decision.effectiveKernel).isEqualTo("exo")
        assertThat(decision.fallbackReason).isEqualTo("emulator_webview_black_screen")
    }

    /**
     * BlueStacks 的平台视频图层也属于高风险环境，
     * 默认 WebView 偏好必须改走 Exo 画面链路。
     */
    @Test
    fun resolve_falls_back_to_exo_for_webview_on_bluestacks() {
        val resolver = RuntimePlayerKernelResolver(
            deviceInfo = TvPlaybackDeviceInfo(
                model = "SM-G998B",
                manufacturer = "samsung",
                brand = "samsung",
                product = "p3sxxx",
                blueStacksImeListenerPort = "9990",
            ),
        )

        val decision = resolver.resolve("webview")

        assertThat(decision.preferredKernel).isEqualTo("webview")
        assertThat(decision.effectiveKernel).isEqualTo("exo")
        assertThat(decision.fallbackReason).isEqualTo("bluestacks_webview_black_screen")
    }

    /**
     * 有些仿真环境会把 Build 字段伪装成真机，
     * 这时只要 EGL 明确标记为 emulation，仍必须视为 WebView 黑屏高风险环境。
     */
    @Test
    fun resolve_falls_back_to_exo_when_egl_runtime_is_emulation() {
        val resolver = RuntimePlayerKernelResolver(
            deviceInfo = TvPlaybackDeviceInfo(
                fingerprint = "samsung/p3sxxx/p3s:13/TQ2B.230505.005.A1/jenkins:user/release-keys",
                model = "SM-G998B",
                manufacturer = "samsung",
                brand = "samsung",
                device = "p3s",
                hardware = "exynos2100",
                product = "p3sxxx",
                eglHardware = "emulation",
            ),
        )

        val decision = resolver.resolve("webview")

        assertThat(decision.preferredKernel).isEqualTo("webview")
        assertThat(decision.effectiveKernel).isEqualTo("exo")
        assertThat(decision.fallbackReason).isEqualTo("emulator_webview_black_screen")
    }

    /**
     * 常规真机环境没有命中黑屏风险特征时，
     * 必须继续尊重用户选择的播放内核。
     */
    @Test
    fun resolve_keeps_requested_kernel_on_normal_device() {
        val resolver = RuntimePlayerKernelResolver(
            deviceInfo = TvPlaybackDeviceInfo(
                fingerprint = "samsung/atv/atv:12/SP1A.210812.016/1234567:user/release-keys",
                model = "QN900B",
                manufacturer = "Samsung",
                brand = "samsung",
                device = "atv",
                hardware = "exynos",
                product = "atv",
            ),
        )

        val decision = resolver.resolve("webview")

        assertThat(decision.preferredKernel).isEqualTo("webview")
        assertThat(decision.effectiveKernel).isEqualTo("webview")
        assertThat(decision.fallbackReason).isNull()
    }
}
