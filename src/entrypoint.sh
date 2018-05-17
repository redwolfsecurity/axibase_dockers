#!/usr/bin/env bash

PACKAGE_TYPE=$1
OS_TYPE=$2

build_ubuntu() {
    ./build.sh
    ./configure                    \
        --prefix=/usr              \
        --sysconfdir=/etc          \
        --localstatedir=/var       \
        --libdir=/usr/lib          \
        --mandir=/usr/share/man    \
        --enable-write_atsd        \
        --enable-write_kafka       \
        --enable-write_log         \
        --disable-write_graphite   \
        --disable-write_http       \
        --disable-write_mongodb    \
        --disable-write_prometheus \
        --disable-write_redis      \
        --disable-write_riemann    \
        --disable-write_sensu      \
        --disable-write_tsdb
    make
    make DESTDIR=/collectd install
    cp -fv /buildfiles/collectd.conf /collectd/etc/collectd.conf
    cp -fv /buildfiles/collectd.conf /collectd/etc/collectd.conf.in
    sed -i "s/version/${version}/" /collectd/DEBIAN/control
    cp -frv /opt /collectd


    cd / && fakeroot dpkg-deb --build /collectd
    #todo version doesn't work
    mv -fv collectd.deb collectd_"$version_$arch".deb
    mkdir -pv /build/"${OS_TYPE}"
    cp -fv collectd_"$version_$arch".deb /build/"${OS_TYPE}"
}

build_rhel() {
    ./build.sh
    ./configure                    \
        --prefix=/usr              \
        --sysconfdir=/etc          \
        --localstatedir=/var       \
        --libdir=/usr/lib          \
        --mandir=/usr/share/man    \
        --enable-write_atsd        \
        --enable-write_kafka       \
        --enable-write_log         \
        --disable-write_graphite   \
        --disable-write_http       \
        --disable-write_mongodb    \
        --disable-write_prometheus \
        --disable-write_redis      \
        --disable-write_riemann    \
        --disable-write_sensu      \
        --disable-write_tsdb
    if [ $? -ne 0 ]; then
        echo "ERROR: configuration failed"
        exit 1
    fi
    cp -fv /buildfiles/collectd.conf src/collectd.conf
    cp -fv /buildfiles/collectd.conf src/collectd.conf.in
    cp -fv /buildfiles/systemd.collectd-axibase.service contrib/systemd.collectd-axibase.service
    cd /
    mv -fv atsd-collectd-plugin collectd-${version}
    tar cjvf collectd-${version}.tar.bz2 collectd-${version}
    mkdir -pv /root/rpmbuild/SOURCES /root/rpmbuild/SPECS
    cp -fv collectd-${version}.tar.bz2 /root/rpmbuild/SOURCES
    cd /root/rpmbuild/SPECS
    rpmbuild -bb collectd.spec     \
        --with write_atsd          \
        --with write_kafka         \
        --with write_log           \
        --without write_graphite   \
        --without write_http       \
        --without write_mongodb    \
        --without write_prometheus \
        --without write_redis      \
        --without write_riemann    \
        --without write_sensu      \
        --without write_tsdb
    if [ $? -ne 0 ]; then
        echo "ERROR: build failed"
        exit 1
    fi
    find /root/rpmbuild/RPMS -name '*.rpm' -exec cp -fv {} /build \;
}

arch=`uname -m`

git clone https://github.com/axibase/atsd-collectd-plugin.git
cd atsd-collectd-plugin/

case ${PACKAGE_TYPE} in
    debian)
        build_ubuntu
        ;;
    rhel)
        build_rhel
        ;;
    *)
        echo "ERROR: Unknown build type"
        ;;
esac
