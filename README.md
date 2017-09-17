# Axibase Time Series Database

## Overview

Axibase Time Series Database is a specialized database for storing and analyzing time series data at scale.

ATSD provides the following advantanges for application developers and data scientists:

- Network API, CSV parsers, Storage Drivers, and Axibase Collector to consolidate timestamped data.
- Data API and API clients for integration with custom Java, Go, Ruby, Python, NodeJS applications and R scripts.
- Meta API and extended data types (Properties, Messages) to model the application's domain and industry-specific relationships.
- SQL support with powerful time-series extensions for scheduled and ad-hoc reporting.
- Built-in visualization library with 15 widgets optimized for building real-time dashboards.
- Integrated rule engine with support for analytical rules and anomaly detection based on ARIMA and Holt-Winters forecasts.

## Image Summary

* Image name: `axibase/atsd:latest`
* Base Image: Ubuntu 16.04
* [Dockerfile](https://github.com/axibase/dockers/blob/master/Dockerfile)

## Start Container

```properties
docker run \
  --detach \
  --name=atsd \
  --restart=always \
  --publish 8088:8088 \
  --publish 8443:8443 \
  --publish 8081:8081 \
  --publish 8082:8082/udp \
  axibase/atsd:latest
```

## Check Installation

```
docker logs -f atsd
```

It may take up to 5 minutes to initialize the database.

You should see 'start completed' message at the end of the `start.log` file.

```
[ATSD] Starting ATSD ...
...
[ATSD] Waiting for ATSD to start. Checking ATSD user interface port 8088 ...
[ATSD] Waiting for ATSD to bind to port 8088 ...( 1 of 20 )
...
[ATSD] ATSD web interface:
[ATSD] http://172.17.0.2:8088
[ATSD] https://172.17.0.2:8443
[ATSD] ATSD start completed.
```

The web interface is accessible on port 8088/http and 8443/https.

## Launch Parameters

| **Name** | **Required** | **Description** |
|:---|:---|:---|
|`--detach` | Yes | Run container in background and print container id. |
|`--hostname` | No | Assign hostname to the container. |
|`--name` | No | Assign a unique name to the container. |
|`--restart` | No | Auto-restart policy. _Not supported in all Docker Engine versions._ |
|`--publish` | No | Publish a container's port to the host. |

## Environment Variables

| **Name** | **Required** | **Description** |
|:---|:---|:---|
|`--env ADMIN_USER_NAME` | No | User name for the built-in administrator account. |
|`--env ADMIN_USER_PASSWORD` | No | [Password](https://github.com/axibase/atsd-docs/blob/master/administration/user-authentication.md#password-requirements) for the built-in administrator.|
|`--env COLLECTOR_USER_NAME` | No | User name for a data collector account. |
|`--env COLLECTOR_USER_PASSWORD` | No | [Password](https://github.com/axibase/atsd-docs/blob/master/administration/user-authentication.md#password-requirements) for a data collector account.|
|`--env COLLECTOR_USER_TYPE` | No | User group for a data collector account, default value is `writer`.|
|`--env DB_TIMEZONE` | No | Database [timezone identifier](https://github.com/axibase/atsd/blob/master/api/network/timezone-list.md).|

View additional launch examples [here](https://github.com/axibase/atsd-docs/blob/master/installation/docker.md#option-1-configure-collector-account-automatically).

## Exposed Ports

| **Name** | **Protocol** | **Description** |
|:---|:---|:---|
| 8088 | http | API, user interface. |
| 8443 | https | API, user interface (secure). |
| 8081 | tcp | Incoming [network commands](https://github.com/axibase/atsd-docs/tree/master/api/network#network-api). |
| 8082 | udp | Incoming [network commands](https://github.com/axibase/atsd-docs/tree/master/api/network#udp-datagrams). |
| 8084 | tcp | Incoming Graphite commands in Python pickle format. |
| 1099 | tcp | JMX |


## Troubleshooting

* Review [Troubleshooting Guide](https://github.com/axibase/atsd-docs/blob/master/installation/troubleshooting.md).

## Validation

* [Verify database installation](https://github.com/axibase/atsd-docs/blob/master/installation/verifying-installation.md).

## Post-installation Steps

* [Basic configuration](https://github.com/axibase/atsd-docs/blob/master/installation/post-installation.md).
* [Getting Started guide](https://github.com/axibase/atsd-docs/blob/master/tutorials/getting-started.md).
