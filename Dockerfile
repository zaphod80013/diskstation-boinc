FROM ubuntu:latest as base
MAINTAINER Ray Sutton <blackhole996@gmail.com>
COPY startup.sh /usr/local/bin/startup.sh
RUN apt-get upgrade; \
    apt-get update; \ 
    apt-get -q install -y boinc-client; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/lib/boinc-client/*; \
    mkdir -p /home/boinc; \
    chown boinc:boinc /home/boinc; \
    chmod 755 /usr/local/bin/startup.sh

FROM base
USER boinc
WORKDIR /home/boinc
ENTRYPOINT ["/usr/local/bin/startup.sh"]
EXPOSE 31416 80 443
VOLUME ["/home/boinc"]
