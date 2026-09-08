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

/**
 * Nang compileSdk cua cac plugin con khai bao muc cu.
 *
 * bonsoir_android 5.1.6 hard-code `compileSdkVersion 33`, trong khi AGP 9 doi
 * it nhat 34 - va 5.1.6 la ban moi nhat trong rang buoc cua bonsoir, nen khong
 * nang dependency de sua duoc.
 *
 * CHI doi compileSdk, tuc phien ban SDK dung de BIEN DICH. Khong dong den
 * targetSdk (quyet dinh hanh vi luc chay) hay minSdk (quyet dinh may nao cai
 * duoc), nen khong thay doi gi ve hanh vi cua app.
 *
 * Goi qua reflection vi kieu extension cua AGP doi qua cac ban lon; goi theo
 * ten phuong thuc thi khong phu thuoc vao phien ban AGP dang dung.
 *
 * PHAI dang ky TRUOC khoi `evaluationDependsOn(":app")` ben duoi: khoi do lam
 * mot so subproject duoc evaluate ngay, va Gradle khong cho goi afterEvaluate
 * tren project da evaluate xong.
 */
val compileSdkToiThieu = 36

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate

        val hienTai = android.javaClass.methods
            .firstOrNull { it.name == "getCompileSdkVersion" && it.parameterCount == 0 }
            ?.invoke(android) as? String
            ?: return@afterEvaluate

        val muc = hienTai.removePrefix("android-").toIntOrNull() ?: return@afterEvaluate
        if (muc >= compileSdkToiThieu) return@afterEvaluate

        val setter = android.javaClass.methods.firstOrNull {
            it.name == "compileSdkVersion" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == Int::class.javaPrimitiveType
        }

        if (setter == null) {
            // Khong im lang bo qua: neu AGP doi API thi phai biet ngay, thay vi
            // nhan lai dung loi compileSdk kho hieu nhu truoc.
            logger.warn(
                "Khong nang duoc compileSdk cua ${project.name} (dang $hienTai). " +
                    "AGP co the da doi API - xem lai doan nay trong build.gradle.kts.",
            )
            return@afterEvaluate
        }

        logger.lifecycle(
            "Nang compileSdk cua ${project.name}: $hienTai -> $compileSdkToiThieu",
        )
        setter.invoke(android, compileSdkToiThieu)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
