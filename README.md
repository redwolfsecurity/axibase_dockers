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

Parameters for the container are specified via environment variables.

| Variable Name | Format | Description |
|------------------|---------|-------------|
| `ATSD_IMPORT_PATH` | `location_1,location_2,...,location_N` | Comma-separated locations of configuration files for ATSD. Each location can be either a file within the container file system or URL |
| `COLLECTOR_IMPORT_PATH` | `location_1,location_2,...,location_N` | Comma-separated locations of configuration files for Collector. Each location can be either a file within the container file system or URL |
| `COLLECTOR_CONFIG` | `file_1:update_1_1,update_1_2;...;update_K:update_K_1,update_K_2,...,update_K_N` | Specifies how ot update Collector configuration files before import. See below for detailed description |

Each location specified in `ATSD_IMPORT_PATH` or `COLLECTOR_IMPORT_PATH` can be:

1. URL address of the configuration file or archive
   ```sh
   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --env ATSD_IMPORT_PATH='https://example.com/atsd-marathon-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://example.com/marathon-jobs.xml' \
     axibase/atsd-sandbox:latest
   ```
2. Absolute path on the container file system to configuration file or archive
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
3. The relative path to the configuration file (archive). In this case the file should be located in the `/import` directory on the container file system.
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

`COLLECTOR_CONFIG` is the semicolon-separated sequence of instructions to edit configuration files for Collector. Each instruction has the form `file-name.xml:updates`.
`updates` is the comma-separated sequence of individual updates applied to the configuration file. Each update can be:

1. A path to a file on the container file system, that contains `key=value` lines
   ```sh
   cat /home/user/aws.conf
   accessKeyId=key
   secretAccessKey=secret

   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /home/user/aws.conf:/aws.conf \
     --env ATSD_IMPORT_PATH='https://github.com/axibase/atsd-use-cases/raw/master/how-to/aws/route53-health-checks/resources/aws-route53-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/aws/route53-health-checks/resources/job_aws_aws-route53.xml' \
     --env COLLECTOR_CONFIG="job_aws_aws-route53.xml:/aws.conf" \
   axibase/atsd-sandbox:latest
   ```
2. Same as previous, but the file is located in `/import` directory, and path to this file is relative
   ```sh
   cat /home/user/import/aws.conf
   accessKeyId=key
   secretAccessKey=secret

   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /home/user/import:/import \
     --env ATSD_IMPORT_PATH='https://github.com/axibase/atsd-use-cases/raw/master/how-to/aws/route53-health-checks/resources/aws-route53-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/aws/route53-health-checks/resources/job_aws_aws-route53.xml' \
     --env COLLECTOR_CONFIG="job_aws_aws-route53.xml:aws.conf" \
     axibase/atsd-sandbox:latest
   ```
3. Just a key-value pair in `key=value` format
   ```sh
   docker run -d -p 8443:8443 -p 9443:9443 -p 8081:8081 \
     --name=atsd-sandbox \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --env ATSD_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/marathon/capacity-and-usage/resources/atsd-marathon-xml.zip' \
     --env COLLECTOR_IMPORT_PATH='https://raw.githubusercontent.com/axibase/atsd-use-cases/master/how-to/marathon/capacity-and-usage/resources/marathon-jobs.xml' \
     --env COLLECTOR_CONFIG='marathon-jobs.xml:server=marathon_hostname,port=8080,userName=my-user,password=my-password' \
     axibase/atsd-sandbox:latest
   ```

Updates `key=new_value` mean substituting or replacing the `key` XML-tag content with `new_value`:

- Before
  ```
  <key>some_content</key>
  ```
- After
  ```
  <key>new_value</key>
  ```

`ATSD_IMPORT_PATH`, `COLLECTOR_IMPORT_PATH`, `COLLECTOR_CONFIG` must not contain space characters. Semicolons and commas in file names, URLs, key and values must be escaped by `\` character, according to the table

| Variable | Escaping |
|----------|----------|
| `ATSD_IMPORT_PATH` | Only `,` must be escaped. Do not escape `;` |
| `COLLECTOR_IMPORT_PATH` | Only `,` must be escaped. Do not escape `;` |
| `COLLECTOR_CONFIG` | Both `,` and `;` must be escaped |

   ```
   ... --env COLLECTOR_CONFIG='config.xml:password=password\,with\;separators' ...
   ```

Additional escaping might be required; this depends on the shell type and version.

> Note: bind-mounted files or directories, i.e. `--volume /file-or-directory-path:...`, should not be removed or renamed between container restarts.

## Explore

*  ATSD web interface on `https://docker_host:8443/`

*  Axibase Collector web interface on `https://docker_host:9443/`
