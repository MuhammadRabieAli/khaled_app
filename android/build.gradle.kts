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

// Workaround for missing namespace in older plugins (must be before evaluationDependsOn)
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // 1. Fix Namespace
                val getNamespace = android::class.java.getMethod("getNamespace")
                if (getNamespace.invoke(android) == null) {
                    val setNamespace = android::class.java.getMethod("setNamespace", String::class.java)
                    val packageName = if (project.name == "isar_flutter_libs") {
                        "dev.isar.isar_flutter_libs"
                    } else {
                        "com.example.${project.name.replace("-", "_")}"
                    }
                    setNamespace.invoke(android, packageName)
                    println("Set namespace for ${project.name} to $packageName")
                }
            } catch (e: Exception) {
               println("Namespace workaround failed for ${project.name}: $e")
            }

            // 2. Fix Compile SDK for isar_flutter_libs (fix lStar error)
            if (project.name == "isar_flutter_libs") {
                try {
                    val setCompileSdkVersion = android::class.java.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    setCompileSdkVersion.invoke(android, 36)
                    println("Forced compileSdkVersion to 36 for ${project.name}")
                } catch (e: Exception) {
                    println("CompileSdk workaround failed for ${project.name}: $e")
                }
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
