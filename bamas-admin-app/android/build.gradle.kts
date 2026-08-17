allprojects {
    repositories {
        google()
        mavenCentral()
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

// ---------------------------------------------------------------------------
// Force every Flutter plugin to compile against a modern Android SDK.
// ---------------------------------------------------------------------------
val enforcedCompileSdk = 36

subprojects {
    afterEvaluate {
        val androidExtension = project.extensions.findByName("android") ?: return@afterEvaluate
        try {
            val currentRaw = androidExtension.javaClass
                .getMethod("getCompileSdkVersion")
                .invoke(androidExtension) as? String
            val current = currentRaw?.removePrefix("android-")?.toIntOrNull() ?: 0

            if (current in 1 until enforcedCompileSdk) {
                androidExtension.javaClass
                    .getMethod("setCompileSdkVersion", Int::class.java)
                    .invoke(androidExtension, enforcedCompileSdk)
                logger.lifecycle(
                    "[bamas] Raised compileSdk for ${project.name}: $current -> $enforcedCompileSdk"
                )
            }
        } catch (e: Exception) {
            logger.warn("[bamas] Could not adjust compileSdk for ${project.name}: ${e.message}")
        }
    }
}

// This MUST remain below the afterEvaluate block above!
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}