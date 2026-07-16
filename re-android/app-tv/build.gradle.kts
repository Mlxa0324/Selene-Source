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

/** 与 Flutter android 共用正式签名；文件缺失时不配置 release 签名。 */
fun loadReleaseKeystoreProperties(): Properties {
    val properties = Properties()
    // re-android 与 Flutter android 同级：../android/key.properties
    val keyFile = rootProject.file("../android/key.properties")
    if (keyFile.exists()) {
        keyFile.inputStream().use { input ->
            properties.load(input)
        }
    }
    return properties
}

val releaseKeystoreProperties = loadReleaseKeystoreProperties()

android {
    // 约束 TV 壳工程的 Android 编译参数，避免与 Flutter 工程互相耦合。
    namespace = "org.moontechlab.selene.tv.app"
    compileSdk = 35

    defaultConfig {
        // 定义 TV 壳独立包名与基础版本信息。
        applicationId = "org.moontechlab.selene.tv.app"
        minSdk = 26
        targetSdk = 35
        // 首个正式 TV 原生版本。
        versionCode = 100
        versionName = "1.0.0"

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

        // 设置页可填任意 http:// 后台，编译期无法预知协议；与 Flutter 壳一致始终放行明文。
        manifestPlaceholders["seleneTvUsesCleartextTraffic"] = "true"
    }

    signingConfigs {
        create("release") {
            val storeFileName = releaseKeystoreProperties.getProperty("storeFile")
            if (!storeFileName.isNullOrBlank()) {
                // Flutter 工程内的 upload-keystore.jks。
                storeFile = rootProject.file("../android/app/$storeFileName")
                storePassword = releaseKeystoreProperties.getProperty("storePassword")
                keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // 继承 defaultConfig 明文放行，便于联调本地/穿透 HTTP 后台。
        }

        release {
            isMinifyEnabled = false
            // 有正式 keystore 时签名；否则退回 debug 签名仍可装，但不应上架。
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = if (releaseSigning?.storeFile?.exists() == true) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
            // 用户在设置里手填 http:// 服务器时，正式包也必须允许 CLEARTEXT。
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
    implementation(project(":feature-tv-home"))
    implementation(project(":feature-tv-search"))
    implementation(project(":feature-tv-history"))
    implementation(project(":feature-tv-favorites"))
    implementation(project(":feature-tv-settings"))
    implementation(project(":feature-tv-live"))
    implementation(project(":feature-tv-detail"))
    implementation(project(":feature-tv-player"))
    implementation(project(":core-design"))
    implementation(project(":core-data"))
    implementation(project(":core-network"))
    implementation(project(":core-player-api"))
    implementation(project(":core-player-exo"))
    implementation(project(":core-player-webview"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.tv.material)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.coil.compose)

    testImplementation(libs.junit4)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
}
