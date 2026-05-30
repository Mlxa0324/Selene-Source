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
include(":feature-tv-player")
