pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "selene-re-android"

include(":app-tv")
include(":core-design")
include(":core-network")
include(":core-data")
include(":core-player-api")
include(":core-player-exo")
include(":core-player-webview")
include(":core-benchmark")
include(":feature-tv-player")
include(":feature-tv-home")
include(":feature-tv-search")
include(":feature-tv-history")
include(":feature-tv-favorites")
include(":feature-tv-settings")
include(":feature-tv-live")
include(":feature-tv-detail")
