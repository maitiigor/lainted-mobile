import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (e.g. geocoding_android 3.3.1) hardcode a stale
// compileSdk in their own android/build.gradle, independent of the
// app module's setting - androidx.fragment/androidx.window now require
// compiling against API 34+. Force every subproject to match the app's
// compileSdk rather than waiting on each plugin to bump its own.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { (it as BaseExtension).compileSdkVersion(36) }
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
