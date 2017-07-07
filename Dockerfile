FROM registry.access.redhat.com/rhel7
MAINTAINER ATSD Developers <dev-atsd@axibase.com>

#default to UTF-8 file.encoding
ENV LANG en_US.utf8

#metadata
LABEL com.axibase.vendor="Axibase Corporation" \
      com.axibase.product="Axibase Time Series Database" \
      com.axibase.code="ATSD" \
      com.axibase.function="database" \
      com.axibase.platform="linux" \
      name="axibase/atsd" \
      vendor="Axibase Corporation" \
      version="16741" \
      release="2" \
      summary="Axibase Time Series Database" \
      description="High-performance database for time-series data with built-in SQL, rule-engine, and visualization." \
      url="https://www.axibase.com" \
      run="docker run \
      --detach \
      --name=atsd \
      --restart=always \
      --publish 8088:8088 \
      --publish 8443:8443 \
      --publish 8081:8081 \
      --publish 8082:8082/udp \
      axibase/atsd:16741" \
      stop="docker stop atsd"

COPY help.1 /
COPY licenses /licenses

#install atsd rpm with yum
RUN REPOLIST=rhel-7-server-rpms,axibase &&\
    printf "[axibase]\nname=Axibase Repository\nbaseurl=https://axibase.com/public/repository/rpm\nenabled=1\ngpgcheck=0\nprotect=1" >> /etc/yum.repos.d/axibase.repo &&\
    yum -y update-minimal --disablerepo "*" --enablerepo rhel-7-server-rpms --setopt=tsflags=nodocs \
      --security --sec-severity=Important --sec-severity=Critical && \
    yum -y install --disablerepo "*" --enablerepo ${REPOLIST} --setopt=tsflags=nodocs atsd && \
    yum clean all

USER axibase

#set hbase distributed mode false
RUN sed -i '/.*hbase.cluster.distributed.*/{n;s/.*/   <value>false<\/value>/}' /opt/atsd/hbase/conf/hbase-site.xml

#jmx, atsd(tcp), atsd(udp), pickle, http, https
EXPOSE 1099 8081 8082/udp 8084 8088 8443
VOLUME ["/opt/atsd"]

ENTRYPOINT ["/bin/bash","/opt/atsd/bin/entrypoint.sh"]
