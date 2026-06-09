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

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAction = Action<Project> {
        if (hasProperty("android")) {
            val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
            val isOldPlugin = project.name == "audioplayers_android"
            val targetVersion = if (isOldPlugin) JavaVersion.VERSION_1_8 else JavaVersion.VERSION_17
            
            try {
                android.compileOptions {
                    sourceCompatibility = targetVersion
                    targetCompatibility = targetVersion
                }
            } catch (e: Exception) {
                // Ignore finalized errors
            }

            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(if (isOldPlugin) org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8 else org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
    
    if (state.executed) {
        configureAction.execute(this)
    } else {
        afterEvaluate(configureAction)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins{
    id("com.google.gms.google-services") version "4.4.4" apply false
}