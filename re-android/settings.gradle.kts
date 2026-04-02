import java.io.File

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

include(":app")

fun includeChildren(parent: String) {
    val parentDir = file(parent)
    if (!parentDir.exists() || !parentDir.isDirectory) return

    parentDir.listFiles()
        ?.filter { it.isDirectory }
        ?.filter {
            File(it, "build.gradle.kts").exists() || File(it, "build.gradle").exists()
        }
        ?.sortedBy { it.name }
        ?.forEach { child ->
            val modulePath = ":$parent:${child.name}"
            include(modulePath)
            project(modulePath).projectDir = child
        }
}

includeChildren("core")
includeChildren("feature")
