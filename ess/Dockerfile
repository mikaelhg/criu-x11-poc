FROM amazoncorretto:8
WORKDIR /app
RUN yum install -y util-linux procps lsof iptables criu xorg-x11-server-Xvfb gtk2 gtk3 libXrender libXtst python3 less screen
COPY *.sh /app/
COPY ess /app/
CMD bash
