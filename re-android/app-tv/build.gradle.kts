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
    namespace = "org.moontechlab.selene.tv.app"
    compileSdk = 35

    defaultConfig {
        // 定义 TV 壳独立包名与基础版本信息。
        applicationId = "org.moontechlab.selene.tv.app"
        minSdk = 26
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
    }

    buildTypes {
        release {
            isMinifyEnabled = false
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

    testImplementation(libs.junit4)
    testImplementation(libs.truth)
    testImplementation(libs.kotlinx.coroutines.test)
}
