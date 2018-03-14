FROM ubuntu:16.04
ENV version=latest LANG=en_US.UTF-8

# metadata
LABEL com.axibase.maintainer="ATSD Developers <dev-atsd@axibase.com>" \
  com.axibase.vendor="Axibase Corporation" \
  com.axibase.product="Axibase Time Series Database" \
  com.axibase.code="ATSD" \
  com.axibase.revision="${version}"

# add entry point and image cleanup script
COPY entry*.sh /
COPY preinit.sh /tmp/

# install and configure
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 26AEE425A57967CFB323846008796A6514F3CB79 \
  && echo "deb [arch=amd64] http://axibase.com/public/repository/deb/ ./" >> /etc/apt/sources.list \
  && apt-get update \
  && LANG=C DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y locales apt-utils \
  && locale-gen en_US.UTF-8 \
  && adduser --disabled-password --quiet --gecos "" axibase \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y atsd wget unzip cron nano iproute2 \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/.*hbase.cluster.distributed.*/{n;s/.*/   <value>false<\/value>/}' /opt/atsd/hbase/conf/hbase-site.xml \
  && /entrycleanup.sh \
  && wget -P /tmp -e robots=off -r -nd https://axibase.com/public/axibase-collector_latest.htm \
  && tar -xzvf /tmp/axibase-collector-*.tar.gz -C /opt/ \
  && mkdir -p /opt/axibase-collector/exploded/webapp \
  && unzip /opt/axibase-collector/lib/axibase-collector.war -d /opt/axibase-collector/exploded/webapp \
  && /tmp/preinit.sh

# jmx, network commands(tcp), network commands(udp), graphite pickle, UI/api http, UI/api https, Collector https
EXPOSE 1099 8081 8082/udp 8084 8088 8443 9443

VOLUME ["/opt/atsd", "/opt/axibase-collector"]

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
