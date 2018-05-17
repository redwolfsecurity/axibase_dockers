#!/usr/bin/env bash

cd $(dirname $(readlink -f $0))

echo "Creating build images"
echo "====================="
docker build -t builder/centos:6 -f src/Dockerfile-centos-6 .
docker build -t builder/centos:7 -f src/Dockerfile-centos-7 .
docker build -t builder/ubuntu:14.04 -f src/Dockerfile-ubuntu-14.04 .
docker build -t builder/ubuntu:16.04 -f src/Dockerfile-ubuntu-16.04 .

mkdir -pv packages

echo
echo "Running build containers"
echo "========================"
docker run --rm --detach --name collectd-centos-6  \
    --mount type=bind,source="$(pwd)"/src,target=/buildfiles \
    --mount type=bind,source="$(pwd)"/src/SPECS,target=/root/rpmbuild/SPECS \
    --mount type=bind,source="$(pwd)"/packages,target=/build \
    builder/centos:6

docker logs -f collectd-centos-6 &> collectd-centos-6.log &

docker run --rm --detach --name collectd-centos-7  \
    --mount type=bind,source="$(pwd)"/src,target=/buildfiles \
    --mount type=bind,source="$(pwd)"/src/SPECS,target=/root/rpmbuild/SPECS \
    --mount type=bind,source="$(pwd)"/packages,target=/build \
    builder/centos:7

docker logs -f collectd-centos-7 &> collectd-centos-7.log &

docker run --rm --detach --name collectd-ubuntu-14.04  \
    --mount type=bind,source="$(pwd)"/src,target=/buildfiles \
    --mount type=bind,source="$(pwd)"/src/DEBIAN,target=/collectd/DEBIAN \
    --mount type=bind,source="$(pwd)"/src/collectd-axibase,target=/collectd/etc/init.d/collectd-axibase \
    --mount type=bind,source="$(pwd)"/packages,target=/build \
    builder/ubuntu:14.04

docker logs -f collectd-ubuntu-14.04 &> collectd-ubuntu-14.04.log &

docker run --rm --detach --name collectd-ubuntu-16.04  \
    --mount type=bind,source="$(pwd)"/src,target=/buildfiles \
    --mount type=bind,source="$(pwd)"/src/DEBIAN,target=/collectd/DEBIAN \
    --mount type=bind,source="$(pwd)"/packages,target=/build \
    builder/ubuntu:16.04

docker logs -f collectd-ubuntu-16.04 &> collectd-ubuntu-16.04.log &

echo "Waiting for build to finish..."
docker wait               \
    collectd-centos-6     \
    collectd-centos-7     \
    collectd-ubuntu-14.04 \
    collectd-ubuntu-16.04

echo "Build finished."
