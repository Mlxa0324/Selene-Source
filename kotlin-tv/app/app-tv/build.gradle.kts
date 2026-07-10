import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

/** 读取本机后台网关配置，文件不存在时返回空配置。 */
fun loadLocalGatewayProperties(): Properties {
    val properties = Properties()
    val localFile = rootProject.file("local.gateway.properties")
    if (localFile.exists()) {
        localFile.inputStream().use { input ->
            properties.load(input)
        }
    }
    return properties
}

/**
 * 转换为安全的 BuildConfig 字符串。
 *
 * @return 已转义的 Java 字符串字面量。
 */
fun String.toBuildConfigString(): String {
    return "\"${replace("\\", "\\\\").replace("\"", "\\\"")}\""
}

val localGatewayProperties = loadLocalGatewayProperties()

android {
    // 约束 TV 壳工程的 Android 编译参数，避免与 Flutter 工程互相耦合。
    namespace = "uk.oxiang.ivy.tv.app"
    compileSdk = 35

    defaultConfig {
        // 定义 TV 壳独立包名与基础版本信息。
        applicationId = "uk.oxiang.ivy.tv.app"
        // 骨架冻结的最低系统版本，供 5 个 feature 子任务消费。
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // 本地私密后台配置来自 git-ignore 文件，未填写时保持空值。
        buildConfigField(
            "String",
            "SELENE_TV_BASE_URL",
            (localGatewayProperties.getProperty("SELENE_TV_BASE_URL") ?: "").toBuildConfigString(),
        )
        buildConfigField(
            "String",
            "SELENE_TV_USERNAME",
            (localGatewayProperties.getProperty("SELENE_TV_USERNAME") ?: "").toBuildConfigString(),
        )
        buildConfigField(
            "String",
            "SELENE_TV_PASSWORD",
            (localGatewayProperties.getProperty("SELENE_TV_PASSWORD") ?: "").toBuildConfigString(),
        )
        buildConfigField(
            "String",
            "SELENE_TV_DANMAKU_BASE_URL",
            (localGatewayProperties.getProperty("SELENE_TV_DANMAKU_BASE_URL") ?: "").toBuildConfigString(),
        )

        // Debug 默认服务本地 HTTP 后台；Release 在 buildTypes 中关闭明文流量。
        manifestPlaceholders["seleneTvUsesCleartextTraffic"] = "true"
    }

    buildTypes {
        debug {
            // 本地后台常用 HTTP 地址，debug 包允许直连便于 TV 端联调。
            manifestPlaceholders["seleneTvUsesCleartextTraffic"] = "true"
        }

        release {
            // Release 默认要求 HTTPS，避免把本地调试策略带到正式包。
            isMinifyEnabled = false
            manifestPlaceholders["seleneTvUsesCleartextTraffic"] = "false"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(project(":core:core-common"))
    implementation(project(":core:core-design"))
    implementation(project(":core:core-player"))
    implementation(project(":feature:feature-home"))
    implementation(project(":feature:feature-detail"))
    implementation(project(":feature:feature-player"))
    implementation(project(":feature:feature-search"))
    implementation(project(":feature:feature-settings"))
    implementation(project(":feature:feature-content"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.tv.material)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.coil.compose)
    implementation(libs.androidx.datastore.preferences)

    testImplementation(libs.junit4)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
}
