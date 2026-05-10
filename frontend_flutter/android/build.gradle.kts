allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            val getNamespaceMethod = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            try {
                if (getNamespaceMethod?.invoke(androidExt) == null) {
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val document = javax.xml.parsers.DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(manifestFile)
                        val packageName = document.documentElement.getAttribute("package")
                        if (packageName.isNotEmpty()) {
                            androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" }?.invoke(androidExt, packageName)
                        }
                    }
                }
            } catch (e: Exception) {
                // Ignore parsing errors for individual plugins
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
