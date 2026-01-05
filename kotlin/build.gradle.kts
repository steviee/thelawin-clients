plugins {
    kotlin("jvm") version "2.0.0"
    kotlin("plugin.serialization") version "2.0.0"
    id("org.jetbrains.dokka") version "1.9.20"
    `maven-publish`
    signing
}

group = "dev.envoice"
version = "0.1.0"

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
                name.set("envoice")
                description.set("Official Kotlin SDK for envoice.dev - Generate ZUGFeRD/Factur-X invoices")
                url.set("https://envoice.dev")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        id.set("envoice")
                        name.set("envoice.dev")
                        email.set("support@envoice.dev")
                    }
                }
                scm {
                    connection.set("scm:git:git://github.com/steviee/envoice-clients.git")
                    developerConnection.set("scm:git:ssh://github.com:steviee/envoice-clients.git")
                    url.set("https://github.com/steviee/envoice-clients")
                }
            }
        }
    }
}
