plugins {
    kotlin("jvm") version "2.0.0"
    kotlin("plugin.serialization") version "2.0.0"
    id("org.jetbrains.dokka") version "1.9.20"
    `maven-publish`
    signing
}

group = "dev.thelawin"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("io.ktor:ktor-client-core:2.3.12")
    implementation("io.ktor:ktor-client-cio:2.3.12")
    implementation("io.ktor:ktor-client-content-negotiation:2.3.12")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.12")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")

    testImplementation(kotlin("test"))
    testImplementation("io.ktor:ktor-client-mock:2.3.12")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}

tasks.test {
    useJUnitPlatform()
}

kotlin {
    jvmToolchain(17)
}

java {
    withJavadocJar()
    withSourcesJar()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            pom {
                name.set("thelawin")
                description.set("Official Kotlin SDK for thelawin.dev - Developer-First ZUGFeRD/Factur-X E-Invoicing API")
                url.set("https://thelawin.dev")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        id.set("thelawin")
                        name.set("thelawin.dev")
                        email.set("support@thelawin.dev")
                    }
                }
                scm {
                    connection.set("scm:git:git://github.com/steviee/thelawin-clients.git")
                    developerConnection.set("scm:git:ssh://github.com:steviee/thelawin-clients.git")
                    url.set("https://github.com/steviee/thelawin-clients")
                }
            }
        }
    }
}
