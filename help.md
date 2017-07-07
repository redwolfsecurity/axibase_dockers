% axibase/atsd:16741
% Axibase Corporation
% July 07, 2017

# DESCRIPTION
High-performance database for time-series data with built-in SQL, rule-engine, and visualization. 

# USAGE
## Start Container

Execute the command as described above.

```sh
axibase@nurswghbs002 ~]# docker run \
>   --detach \
>   --name=atsd \
>   --restart=always \
>   --publish 8088:8088 \
>   --publish 8443:8443 \
>   --publish 8081:8081 \
>   --publish 8082:8082/udp \
>   --env COLLECTOR_USER_NAME=data-agent \
>   --env COLLECTOR_USER_PASSWORD=Pwd78_ \
>   axibase/atsd:16741
Unable to find image 'axibase/atsd:16741' locally
latest: Pulling from axibase/atsd
bf5d46315322: Pull complete
9f13e0ac480c: Pull complete
e8988b5b3097: Pull complete
40af181810e7: Pull complete
e6f7c7e5c03e: Pull complete
ca48528e7708: Pull complete
de225e971cf6: Pull complete
6a3419ba188d: Pull complete
Digest: sha256:f2c2957b1ffc8dbb24501495e98981899d2b018961a7742ff6adfd4f1e176429
Status: Downloaded newer image for axibase/atsd:16741
14d1f27bf0c139027b5f69009c0c5007d35be92d61b16071dc142fbc75acb36a
```

It may take up to 5 minutes to initialize the database.

## Check Installation

```
docker logs -f atsd
```

You should see an _ATSD start completed_ message at the end of the `start.log` file.


```
...
 * [ATSD] Starting ATSD ...
 * [ATSD] ATSD not running.
 * [ATSD] ATSD java version "1.7.0_111"
 * [ATSD] Waiting for ATSD to start. Checking ATSD web-interface port 8088 ...
 * [ATSD] Waiting for ATSD to bind to port 8088 ...( 1 of 20 )
...
 * [ATSD] Waiting for ATSD to bind to port 8088 ...( 11 of 20 )
 * [ATSD] ATSD web interface:
...
 * [ATSD] http://172.17.0.2:8088
 * [ATSD] https://172.17.0.2:8443
 * [ATSD] ATSD start completed.
```

ATSD web interface is accessible on port 8088/http and 8443/https.

## Launch Parameters

| **Name** | **Required** | **Description** |
|:---|:---|:---|
|`--detach` | Yes | Run container in background and print container id. |
|`--hostname` | No | Assign hostname to the container. |
|`--name` | No | Assign a unique name to the container. |
|`--restart` | No | Auto-restart policy. _Not supported in all Docker Engine versions._ |
|`--publish` | No | Publish a container's port to the host. |
|`--env COLLECTOR_USER_NAME` | No | User name for a data collector account. |
|`--env COLLECTOR_USER_PASSWORD` | No | Password for a data collector account, subject to [requirements](../administration/user-authentication.md#password-requirements).|
|`--env COLLECTOR_USER_TYPE` | No | User group for a data collector account, default value is `writer`.|

## Exposed Ports

* 8088 – http
* 8443 – https
* 8081 – TCP network commands
* 8082 – UDP network commands

## Port Mappings

Depending on your Docker host network configuration, you may need to change port mappings in case some of the published ports are already taken.

```sh
Cannot start container <container_id>: failed to create endpoint atsd on network bridge:
Bind for 0.0.0.0:8088 failed: port is already allocated
```

```properties
docker run \
  --detach \
  --name=atsd \
  --restart=always \
  --publish 8088:8088 \
  --publish 8443:8443 \
  --publish 8081:8081 \
  --publish 8082:8082/udp \
  axibase/atsd:16741
```
