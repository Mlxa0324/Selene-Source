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

rootProject.name = "kotlin-tv"

include(":app:app-tv")
include(":core:core-common")
include(":core:core-design")
include(":core:core-player")
include(":feature:feature-home")
include(":feature:feature-detail")
include(":feature:feature-player")
include(":feature:feature-search")
include(":feature:feature-settings")
include(":feature:feature-content")

project(":app:app-tv").projectDir = file("app/app-tv")
project(":core:core-common").projectDir = file("core/core-common")
project(":core:core-design").projectDir = file("core/core-design")
project(":core:core-player").projectDir = file("core/core-player")
project(":feature:feature-home").projectDir = file("feature/feature-home")
project(":feature:feature-detail").projectDir = file("feature/feature-detail")
project(":feature:feature-player").projectDir = file("feature/feature-player")
project(":feature:feature-search").projectDir = file("feature/feature-search")
project(":feature:feature-settings").projectDir = file("feature/feature-settings")
project(":feature:feature-content").projectDir = file("feature/feature-content")
