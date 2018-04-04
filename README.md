# Overview

The image contains [Axibase Time Series Database](https://github.com/axibase/atsd) and [Axibase Collector](https://github.com/axibase/axibase-collector) instances. 

The Axibase Collector instance is pre-configured to send data into the local ATSD instance.

The collector instance will automatically initiate the [Docker](https://github.com/axibase/axibase-collector/blob/master/jobs/docker.md) job if the `run` command mounts `/var/run/docker.sock` into the container.

## Image Contents

* [Axibase Time Series Database](https://github.com/axibase/atsd)
* [Axibase Collector](https://github.com/axibase/axibase-collector)
* [collectd](https://github.com/axibase/atsd/tree/master/integration/collectd)

## Launch Container

```sh
docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
  --name=atsd-sandbox \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  axibase/atsd-sandbox:latest
```

## Container Parameters

| Variable Name | Description |
|------------------|-------------|
| `ATSD_IMPORT_PATH` | Comma-separated paths to files imported into **ATSD**. Path can refer to a file on the mounted file system or to a URL from which the file will be downloaded. |
| `COLLECTOR_IMPORT_PATH` | Comma-separated paths to files imported into **Collector**. Path can refer to a file on the mounted file system or to a URL from which the file will be downloaded. |
| `SERVER_URL` | Define convenient server URL |
| `WEBHOOK` | Create webhook users from predefined set of templates, separated by comma |
| `EMAIL_CONFIG` | Path to a file with Mail Client configuration parameters |
| `COLLECTOR_CONFIG` | Specifies parameters to be replaced in Collector configuration files before the import. |

### Path Formats

This path format is used in `ATSD_IMPORT_PATH` , `COLLECTOR_IMPORT_PATH`, `COLLECTOR_CONFIG` and `EMAIL_CONFIG` variables

1. **URL address** of the file:
   ```sh
   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --env ATSD_IMPORT_PATH='https://example.com/atsd-marathon-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://example.com/marathon-jobs.xml' \
     axibase/atsd-sandbox:latest
   ```
2. **Absolute path** on the container file system to the file:
   ```sh
   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --volume /home/user/atsd-marathon-xml.zip:/atsd-marathon-xml.zip \
     --volume /home/user/marathon-jobs.xml:/marathon-jobs.xml \
     --env ATSD_IMPORT_PATH='/atsd-marathon-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='/marathon-jobs.xml' \
     axibase/atsd-sandbox:latest
   ```
3. **Relative path** to the the file. In this case the file should be placed in the `/import` directory on the container file system.
    ```sh
    mkdir /home/user/import
    cp atsd-marathon-xml.zip /home/user/import
    cp marathon-jobs.xml /home/user/import
    docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
      --name=atsd-sandbox \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume /home/user/import:/import \
      --env ATSD_IMPORT_PATH='atsd-marathon-xml.zip' \
      --env COLLECTOR_IMPORT_PATH='marathon-jobs.xml' \
      axibase/atsd-sandbox:latest
   ```

### File Import Parameters

`ATSD_IMPORT_PATH` and `COLLECTOR_IMPORT_PATH` variables must be specified using the following format: `path_1,path_2,...,path_N` where each path can refer to either an XML file or zip/tar.gz archive. See [path formats](#path-formats).

### Mail Client Configuration

`EMAIL_CONFIG` variable specifies the file to read Mail Client configuration from. See [path formats](#path-formats).
Supported configuration parameters.

| Property | Description | Default value |
|----------|-------------|---------------|
| `enable` | Enable E-Mail notifications | `on` |
| `server_name` | Server specified in the "From" field, for example `My ATSD Server` | `Axibase TSD` |
| `server` | Hostname or IP address of your mail server, for example smtp.example.com | - |
| `port` | Mail server port | - |
| `sender` | Address specified in the "From" field, for example notify@example.com | - |
| `user` | Username of the mailbox user | - |
| `password` | Password of the mailbox user | - |
| `auth` | Enable authentication | - |
| `ssl` | Enable SSL encryption | `on` |
| `upgrade_ssl` | Upgrade an insecure connection to a secure connection using SSL/TLS | `on` |

These parameters can be set to `on`/`off` or `true`/`false`:

- enable
- auth
- ssl
- upgrade_ssl

Sample configuration:

```
server=mail.example.org
port=587
user=myuser@example.org
password=secret
ssl=true
upgrade_ssl=true
```

### Server URL

If `SERVER_URL` variable is defined, then `server.url` ATSD Server Property will be set to value of this variable.

### Webhook Templates

`WEBHOOK` environment variable specifies which webhook user accounts will be created from templates at first start.
The list of possible user templates:

- aws-cw
- github
- jenkins
- slack
- telegram

Each webhook user will have the same name as template. Webhook URLs are defined as described [here](https://github.com/axibase/atsd/blob/master/api/data/messages/webhook.md#sample-urls)

### Job Configuration Parameters

`COLLECTOR_CONFIG` is the semicolon-separated sequence of instructions to edit configuration files imported into Collector. 

Each instruction should be specified in the format `file_name.xml:/path/to/properties_file` or `file_name.xml:key1=value1,key2=value2` and will cause the attributes in the XML file to be updated with new values prior to importing the file into Collector.

Instructions can be specified as follows:

1. A path to a file on the container file system (see [path formats](#path-formats])), that contains `key=value` lines:
   ```sh
   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /home/user/aws.conf:/aws.conf \
     --env ATSD_IMPORT_PATH='https://github.com/axibase/atsd-use-cases/raw/master/how-to/aws/route53-health-checks/resources/aws-route53-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/aws/route53-health-checks/resources/job_aws_aws-route53.xml' \
     --env COLLECTOR_CONFIG="job_aws_aws-route53.xml:/aws.conf" \
   axibase/atsd-sandbox:latest
   ```
   ```sh
   cat /home/user/aws.conf
   ```
   ```ls
   accessKeyId=key
   secretAccessKey=secret
   ```
2. A key-value pair in `key=value` format:
   ```sh
   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --env ATSD_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/marathon/capacity-and-usage/resources/atsd-marathon-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/marathon/capacity-and-usage/resources/marathon-jobs.xml' \
     --env COLLECTOR_CONFIG='marathon-jobs.xml:server=marathon_hostname,port=8080,userName=my-user,password=my-password' \
     axibase/atsd-sandbox:latest
   ```

The XML file update involves replacement of XML tag values, identified with `key`, with new values, for example:

  ```
  --env COLLECTOR_CONFIG='marathon-jobs.xml:server=mar1.example.com,userName=netops,password=1234456'
  ```

- Before
  ```xml
  <server>marathon_hostname</server>
  <port>8080</port>
  <userName>axibase</userName>
  <password></password>
  ```
- After
  ```xml
  <server>mar1.example.com</server>
  <port>8080</port>
  <userName>netops</userName>
  <password>1234456</password>  
  ```
  
### Parameters Syntax

The variables must not contain whitespace characters.

Semicolons and commas in file names, URLs, key and values must be escaped by `\` character as specified below:

| Variable | Escaping |
|----------|----------|
| `ATSD_IMPORT_PATH` | Only `,` must be escaped. Do not escape `;` |
| `COLLECTOR_IMPORT_PATH` | Only `,` must be escaped. Do not escape `;` |
| `COLLECTOR_CONFIG` | Both `,` and `;` must be escaped |

Variables `WEBHOOK`, `SERVER_URL`, `EMAIL_CONFIG` do not require special escaping for `,` and `;`.

   ```
   ... --env COLLECTOR_CONFIG='config.xml:password=password\,with\;separators' ...
   ```

Additional escaping might be required depending on the shell type and version.

> Note: files or directories mounted into the container, i.e. `--volume /home/user/import:/import`, should not be removed or renamed between container restarts.

## Explore

*  ATSD web interface on `https://docker_host:8443/`

*  Axibase Collector web interface on `https://docker_host:9443/`
