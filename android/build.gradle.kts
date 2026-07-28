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

    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                android.compileSdkVersion(36)
                if (android.namespace == null) {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val match = Regex("""package="([^"]+)"""").find(manifestText)
                        if (match != null) {
                            android.namespace = match.groupValues[1]
                        }
                    }
                    if (android.namespace == null) {
                        android.namespace = "com.plugin." + project.name.replace("-", "_").replace(".", "_")
                    }
                }
                android.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                android.compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
