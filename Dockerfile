# syntax=docker/dockerfile:experimental

FROM openjdk:13-jdk AS BUILD
WORKDIR /build
COPY . /build
RUN --mount=type=cache,id=criu-x11-poc,target=/root/.gradle ./gradlew build -s --no-daemon bootJar

FROM openjdk:13-jdk
WORKDIR /app
COPY --from=BUILD /build/build/libs/app.jar /app/app.jar
ENV _JAVA_OPTIONS "-Xmx64m -Xms64m -XX:+ExitOnOutOfMemoryError"
CMD java -jar /app/app.jar
