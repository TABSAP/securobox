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

    // ML Kit AARs (google_mlkit_commons, etc.) reference platform attrs
    // introduced in API 31 (e.g. android:attr/lStar). Their own compileSdk
    // defaults can be lower than the app's, which makes
    // :verifyReleaseResources fail with "resource android:attr/lStar not
    // found". Force the floor up for every Android library subproject so
    // release builds link cleanly. Must be registered before
    // evaluationDependsOn(":app") below, otherwise the subprojects have
    // already been evaluated by the time the hook runs.
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            if ((androidExt.compileSdkVersion?.substringAfter("android-")?.toIntOrNull() ?: 0) < 34) {
                androidExt.compileSdkVersion(34)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
