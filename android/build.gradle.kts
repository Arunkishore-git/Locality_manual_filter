buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.3.15")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuilder: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuilder)

subprojects {
    val newSubprojectBuildDir: Directory = newBuilder.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
