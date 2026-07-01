plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    // 约束 WebView 兜底播放器模块的 Android 编译参数。
    namespace = "org.moontechlab.selene.tv.core.player.webview"
    compileSdk = 35

    defaultConfig {
        // 对齐 TV 壳当前最低系统版本。
        minSdk = 26
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
    implementation(project(":core-design"))
    implementation(project(":core-player-api"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit4)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
}
