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

rootProject.name = "FocusCycleAndroid"

include(
    ":app-phone",
    ":app-wear",
    ":core-domain",
    ":core-data",
    ":core-sync",
    ":core-health",
    ":core-ui"
)
