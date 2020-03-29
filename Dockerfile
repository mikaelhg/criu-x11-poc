FROM amazoncorretto:11 AS BUILD
WORKDIR /build
COPY . /build
RUN ./gradlew build -s --no-daemon build

FROM amazoncorretto:11
WORKDIR /app
RUN yum install -y util-linux procps lsof iptables criu xorg-x11-server-Xvfb gtk2 gtk3 libXrender libXtst python3 less
COPY *.sh /app/
COPY --from=BUILD /build/build/libs/app.jar /app/app.jar
ENV _JAVA_OPTIONS "-Xmx64m -Xms64m -XX:+ExitOnOutOfMemoryError"
CMD java -jar /app/app.jar
