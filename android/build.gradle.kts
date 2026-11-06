allprojects {
    repositories {
        // Mirror of Google's Maven for networks where dl.google.com is
        // unreachable (see settings.gradle.kts note).
        maven("https://maven.aliyun.com/repository/google")
        google()
        mavenCentral()
    }
}

// Some Flutter plugins (e.g. flutter_secure_storage) declare their own
// buildscript AGP. Reuse the host project's already-cached AGP instead of
// fetching another copy of com.android.tools.build:gradle at build time.
subprojects {
    project.buildscript.configurations.matching { it.name == "classpath" }.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools.build" &&
                requested.name == "gradle"
            ) {
                useVersion("8.11.1")
                because("reuse the host project's cached AGP")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
