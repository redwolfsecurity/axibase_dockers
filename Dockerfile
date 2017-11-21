FROM ubuntu:16.04
ENV version=17933 LANG=en_US.UTF-8

# metadata
LABEL com.axibase.maintainer="ATSD Developers <dev-atsd@axibase.com>" \
  com.axibase.vendor="Axibase Corporation" \
  com.axibase.product="Axibase Time Series Database" \
  com.axibase.code="ATSD" \
  com.axibase.revision="${version}"

# add entry point and image cleanup script
COPY entry*.sh /  

# install and configure
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv-keys 26AEE425A57967CFB323846008796A6514F3CB79 \
  && echo "deb [arch=amd64] http://axibase.com/public/repository/deb/ ./" >> /etc/apt/sources.list \
  && apt-get update \
  && LANG=C DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y locales apt-utils \
  && locale-gen en_US.UTF-8 \
  && adduser --disabled-password --quiet --gecos "" axibase \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y atsd=${version} \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/.*hbase.cluster.distributed.*/{n;s/.*/   <value>false<\/value>/}' /opt/atsd/hbase/conf/hbase-site.xml \
  && /entrycleanup.sh;

USER axibase

# jmx, network commands(tcp), network commands(udp), graphite pickle, UI/api http, UI/api https
EXPOSE 1099 8081 8082/udp 8084 8088 8443

VOLUME ["/opt/atsd"]

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
