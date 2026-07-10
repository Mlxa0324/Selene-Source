plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    // 约束 TV 播放器模块（协议 + ExoPlayer + WebView）的 Android 编译参数。
    namespace = "uk.oxiang.ivy.tv.core.player"
    compileSdk = 35

    defaultConfig {
        // 骨架冻结的最低系统版本，供 5 个 feature 子任务消费。
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        // WebView 播放画面层通过 Compose AndroidView 注入播放器壳。
        compose = true
    }
}

dependencies {
    // 复用 core-design 的协程调度器分层（DispatcherProvider/AppDispatchers）。
    implementation(project(":core:core-design"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.media3.exoplayer)
    implementation(libs.androidx.media3.ui)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit4)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
}
