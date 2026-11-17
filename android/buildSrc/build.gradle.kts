plugins {
    `java-library`
}

repositories {
    google()
    mavenCentral()
}

dependencies {
    compileOnly("com.android.tools.build:gradle:8.12.1")
    compileOnly("org.ow2.asm:asm:9.8")
}
