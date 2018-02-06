# Collectd Docker Image

This image provides a Dockerized collectd configuration to gather operating system statistics from the underlying Docker host instead of a container where it's launched.

The collectd agent started within the container is automatically configured to send metrics into an Axibase Time Series Database instance using the [write_atsd](https://github.com/axibase/atsd-collectd-plugin) plugin. 

The target ATSD instance is specified in the `--atsd-url` argument.

## Prepare Image

### Docker Hub

* Use an existing image published on [Docker Hub](https://hub.docker.com/r/axibase/collectd/)

```
docker pull axibase/collectd
```

### Build Image from Sources

* Download [Dockerfile](Dockerfile) to a Docker host connected to hub.docker.com

* Build image

```
docker build -t axibase/collectd .
```

### Download Image

* Download a pre-built image file from [axibase.com](https://axibase.com/public/docker-axibase-collectd.tar.gz)

* Import the image into the Docker host

```
docker load < docker-axibase-collectd.tar.gz
```

## Start Container

### Basic Configuration

* Start Docker container

```ls
docker run -d -v /:/rootfs:ro --pid=host --net=host \
    --name=collectd axibase/collectd \
    --atsd-url=tcp://atsd_host:tcp_port \
    --fqdn=false
```

* The `fqdn` option is used to set Collectd [FQDNLookup](https://collectd.org/wiki/index.php/FQDNLookup) setting. It controls how a hostname is chosen. When enabled, the hostname of the node is set to the fully qualified domain name 


### `lvs` Configuration

This configuration reads `lvs` command output and therefore must be launched with elevated privileges. The collected data is useful when docker is configured in [`direct-lvm`](https://docs.docker.com/engine/userguide/storagedriver/device-mapper-driver/#/configure-direct-lvm-mode-for-production) mode. 

```ls
docker run -d -v /:/rootfs:ro --privileged=true \
    --pid=host --net=host \
    --name=collectd axibase/collectd \
    --atsd-url=tcp://atsd_host:tcp_port \
    --fqdn=false \
    --lvs
```

The `lvs` output is processed with `lvs.sh` script, invoked by the collectd's native [`exec`](https://collectd.org/documentation/manpages/collectd-exec.5.shtml) plugin. The `lvs.sh` script reads the output into a tabular structure and generates `PUTVAL` commands containing LVM statistics for each logical volume:

```ls
PUTVAL nurswgdkr001/exec-lvs-data%/gauge-volume_group=vg0;logical_volume=thinpool N:4.52
```

### Credits

* [Carles Amigó](https://github.com/fr3nd/docker-collectd) for the idea to re-mount rootfs.

### Troubleshooting

If there are some problems grep collectd logs for errors to find out the reason:

```ls
docker exec -it collectd cat /var/log/collectd.log | grep error
```
