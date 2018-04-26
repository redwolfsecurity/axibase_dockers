FROM debian:jessie
MAINTAINER Axibase
#metadata
LABEL com.axibase.vendor="Axibase Corporation" \
 com.axibase.product="collectd with write_atsd plugin" \
 com.axibase.code="collectd-atsd" \
 com.axibase.revision="5.6.1"

RUN apt-get update && apt-get install -y \
      autoconf \
      automake \
      autotools-dev \
      bison \
      build-essential \
      curl \
      flex \
      git \
      iptables-dev \
      libcurl4-gnutls-dev \
      libdbi0-dev \
      libesmtp-dev \
      libganglia1-dev \
      libgcrypt11-dev \
      libglib2.0-dev \
      libhiredis-dev \
      libltdl-dev \
      liblvm2-dev \
      libmemcached-dev \
      libmnl-dev \
      libmodbus-dev \
      libmysqlclient-dev \
      libopenipmi-dev \
      liboping-dev \
      libow-dev \
      libpcap-dev \
      libperl-dev \
      libpq-dev \
      libprotobuf-c-dev \
      librabbitmq-dev \
      librrd-dev \
      libsensors4-dev \
      libsnmp-dev \
      libtokyocabinet-dev \
      libtokyotyrant-dev \
      libtool \
      libupsclient-dev \
      libvirt-dev \
      libxml2-dev \
      libyajl-dev \
      linux-libc-dev \
      pkg-config \
      protobuf-c-compiler \
      python-dev \
      sudo && \
      rm -rf /usr/share/doc/* && \
      rm -rf /usr/share/info/* && \
      rm -rf /tmp/* && \
      rm -rf /var/tmp/*

RUN adduser --disabled-password --quiet --gecos "" axibase \
  && echo "axibase ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers
WORKDIR /usr/src
RUN git clone https://github.com/axibase/atsd-collectd-plugin.git -b df collectd
WORKDIR /usr/src/collectd
RUN ./build.sh
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/collectd \
    --without-libstatgrab \
    --without-included-ltdl \
    --disable-static
RUN make all
RUN make install
RUN make clean
COPY collectd.conf /etc/collectd/collectd.conf
COPY lvs.sh /etc/collectd/lvs.sh
RUN chmod +x /etc/collectd/lvs.sh
ADD lvs.conf /
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
