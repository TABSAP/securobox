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

    // Some plugins (e.g. google_mlkit_*) still compile their Android module
    // with source/target Java 8, which the JDK reports as "obsolete". They
    // are third-party modules we can't change; silence the cosmetic warning
    // with the flag the JDK itself recommends. Changing the Java version
    // instead would risk a Java/Kotlin jvmTarget mismatch.
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }

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
            // Some third-party plugins (e.g. receive_sharing_intent) still
            // declare Java 8 while their Kotlin compiles to the JDK's default
            // target (17), which fails Gradle's "Inconsistent JVM-target"
            // check. Force every Android library subproject's Java to 17 so it
            // matches the app and its own Kotlin, keeping the toolchain aligned.
            androidExt.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExt.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
