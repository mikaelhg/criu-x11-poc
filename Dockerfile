FROM amazoncorretto:11 AS BUILD
WORKDIR /build
COPY . /build
RUN ./gradlew build -s --no-daemon build

FROM amazoncorretto:11
WORKDIR /app

RUN yum install -y util-linux procps lsof iptables criu \
    xorg-x11-server-Xvfb gtk2 gtk3 libXrender libXtst \
    python3 less git

RUN amazon-linux-extras install -y epel

RUN yum install -y git make gcc automake autobuild asciidoc xmlto \
  protobuf-devel protobuf-c-devel libnet-devel libcap-devel libnl3-devel python2-future \
  gnutls-devel libbsd-devel nftables-devel

RUN wget -qO- http://download.openvz.org/criu/criu-3.13.tar.bz2 | tar xvj

RUN cd criu-3.13 && make

#COPY *.sh /app/
#COPY --from=BUILD /build/build/libs/app.jar /app/app.jar
#ENV _JAVA_OPTIONS "-Xmx64m -Xms64m -XX:+ExitOnOutOfMemoryError"
CMD java -jar /app/app.jar
