#!/bin/bash
trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
DISTR_HOME="/opt/atsd"
ATSD_ALL="${DISTR_HOME}/bin/atsd-all.sh"
HBASE="`readlink -f ${DISTR_HOME}/hbase/bin/hbase`"
HBASE_DAEMON="`readlink -f ${DISTR_HOME}/hbase/bin/hbase-daemon.sh`"
DFS_STOP="`readlink -f ${DISTR_HOME}/hadoop/sbin/stop-dfs.sh`"
LOGFILESTART="`readlink -f ${DISTR_HOME}/atsd/logs/start.log`"
LOGFILESTOP="`readlink -f ${DISTR_HOME}/atsd/logs/stop.log`"
ZOOKEEPER_DATA_DIR="${DISTR_HOME}/hbase/zookeeper"

HTTP_FOUND_CODE="302 Found"
WGET_SUCCESS_CODE=0
WGET_NETWORK_FAILURE_CODE=4

FIRST_START_MARKER="/first-start"
IMPORT_DIR="/import"
TMP_IMPORT_DIR="/tmp/import"
TMP_DOWNLOAD_DIR="/tmp/import-download"
DOCKER_SOCKET="/var/run/docker.sock"

ATSD_ADMIN_USER_NAME=axibase
ATSD_ADMIN_USER_PASSWORD=axibase

ATSD_COLLECTOR_USER_NAME=collector
ATSD_COLLECTOR_USER_PASSWORD=collector

COLLECTOR_USER_NAME=axibase
COLLECTOR_USER_PASSWORD=axibase

declare atsd_import_list
declare collector_import_arg
declare collector_execute_arg
declare import_path

function split_by {
    local split_character=$1
    local str_to_split=$2
    # Remove occurrences of the splitting character not preceded by '\',
    # next remove occurrences of '\' that precede the splitting character
    echo "$str_to_split" | sed "s/\\([^\\\\]\\)$split_character/\\1 /g;s/\\\\\\($split_character\\)/\\1/g"
}

function xml_escape {
    local str_to_escape=$1
    # Escape & < > ' " symbols
    echo "$str_to_escape" | sed "s/\&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/'/\&apos;/g;s/\"/\&quot;/g"
}

function sed_escape {
    local str_to_escape=$1
    # Escape '\', '/' and '&' symbols
    echo "$str_to_escape" | sed 's:[\/&]:\\&:g'
}

function concat_with {
    local left=$1
    local separator=$2
    local right=$3
    if [ -n "$left" ]; then
        echo -n "$left$separator"
    fi
    echo "$right"
}

function resolve_file {
    function download_or_fail {
        local url=$1
        local fatal_error_retries=3
        local retry_delay=5
        while [[ ${fatal_error_retries} > 0 ]]; do
            echo "Downloading $url"
            wget --retry-connrefused --waitretry=${retry_delay} \
                -P "$TMP_DOWNLOAD_DIR" "$url"
            local wget_exit_code=$?
            if [ ${wget_exit_code} -eq ${WGET_SUCCESS_CODE} ]; then
                return
            elif [ ${wget_exit_code} -eq ${WGET_NETWORK_FAILURE_CODE} ]; then
                sleep ${retry_delay}
                fatal_error_retries=$((fatal_error_retries-1))
                if [[ ${fatal_error_retries} > 0 ]]; then
                    echo "WARNING: wget network error, retry"
                fi
            else
                break
            fi
        done
        echo "ERROR: unable to download '$url'"
        exit 1
    }

    local current_path=$1
    # Resolve file by URL, absolute path or relative path in $IMPORT_DIR directory
    if [[ "$current_path" =~ (ftp|https?)://.* ]]; then
        download_or_fail "$current_path"
        local file_name=$(ls -1 "$TMP_DOWNLOAD_DIR")
        import_path="$TMP_IMPORT_DIR"/${file_name%\?*}
        mv "$TMP_DOWNLOAD_DIR"/"$file_name" "$import_path"
    elif [[ "$current_path" =~ /.* ]]; then
        if [[ ! -f "$current_path" ]]; then
            echo "ERROR: File '$current_path' doesn't exist"
            exit 1
        fi
        cp "$current_path" "$TMP_IMPORT_DIR"
        import_path="$TMP_IMPORT_DIR"/$(basename "$current_path")
    else
        local source_path="$IMPORT_DIR"/"$current_path"
        import_path="$TMP_IMPORT_DIR"/"$current_path"
        if [[ ! -f "$source_path" ]]; then
            echo "ERROR: File '$source_path' doesn't exist"
            exit 1
        fi
        cp "$source_path" "$import_path"
    fi
}

function prepare_import {
    function extract_job_name {
        local file_path=$1
        sed -n '/<com.axibase.collector.model.job./{n;s/.*<name>\(.*\)<\/name>.*/\1/p;q}' "$file_path"
    }

    function prepare_import_by_spec {
        function update_atsd_import_list {
            local import_path=$1
            atsd_import_list="$atsd_import_list $import_path"
        }

        function update_collector_argument {
            local import_path=$1
            local job_name=$(extract_job_name "$import_path")
            collector_import_arg=$(concat_with "$collector_import_arg" , "$import_path")
            collector_execute_arg=$(concat_with "$collector_execute_arg" , "$job_name")
        }

        local import_spec=$1
        local import_func=$2
        mkdir -p "$IMPORT_DIR"
        mkdir -p "$TMP_IMPORT_DIR"
        mkdir -p "$TMP_DOWNLOAD_DIR"
        for current_path in ${import_spec//,/ }; do
            resolve_file "$current_path"
            ${import_func} "$import_path"
        done
        rm -rf "$TMP_DOWNLOAD_DIR"
    }

    function update_entry {
        local file_path=$1
        local file_to_edit=$2
        local key=$3
        local right_side=$4
        if ! grep -qE "<$key( [^>]*)?>" "$file_path"; then
            echo "WARNING: Tag '$key' not found in '$file_to_edit'"
            continue
        fi
        local value=$(sed_escape $(xml_escape "$right_side"))
        sed -i "/<$key.*>.*<\/$key>/s/>.*</>$value</" "$file_path"
        if [ "$key" = password ]; then
            sed -i "s/<password/& encrypted=\"false\"/" "$file_path"
        fi
    }

    function update_from_file {
        local file_path=$1
        local file_to_edit=$2
        local file_with_updates=$3
        cat "$file_with_updates" | while read edit_line; do
            local edit_line_key=${edit_line%%=*}
            local edit_line_value=${edit_line#*=}
            update_entry "$file_path" "$file_to_edit" "$edit_line_key" "$edit_line_value"
        done
    }

    function update_import_configs {
        if [ -n "$COLLECTOR_CONFIG" ]; then
            local file_edits=$(split_by \; "$COLLECTOR_CONFIG")
            for file_edit in ${file_edits}; do
                local file_to_edit=${file_edit%%:*}
                local file_path="$TMP_IMPORT_DIR"/"$file_to_edit"
                if [ -f "$file_path" ]; then
                    echo "Updating file '$file_to_edit' for import"
                else
                    echo "WARNING: Can't update '$file_to_edit', file doesn't exist"
                    continue
                fi
                local parameter_edits=$(split_by , "${file_edit#*:}")
                for parameter_edit in ${parameter_edits}; do
                    local key=${parameter_edit%%=*}
                    local right_side=${parameter_edit#*=}
                    if [ "$key" == "$right_side" ]; then
                        resolve_file "$key"
                        update_from_file "$file_path" "$file_to_edit" "$import_path"
                    else
                        update_entry "$file_path" "$file_to_edit" "$key" "$right_side"
                    fi
                done
            done
        fi
    }

    if [ -f "$FIRST_START_MARKER" ]; then
        if [ -n "$ATSD_IMPORT_PATH" ]; then
            prepare_import_by_spec "$ATSD_IMPORT_PATH" update_atsd_import_list
        fi
        if [ -n "$COLLECTOR_IMPORT_PATH" ]; then
            prepare_import_by_spec "$COLLECTOR_IMPORT_PATH" update_collector_argument
            JOB_PATH=-job-path="$collector_import_arg"
            update_import_configs
        fi
    fi
}

function start_atsd {
    function set_tz {
        # set custom timezone
        if [ -n "$DB_TIMEZONE" ]; then
            echo "[ATSD] Database timezone set to '$DB_TIMEZONE'." | tee -a  $LOGFILESTART
            echo "export JAVA_PROPERTIES=\"-Duser.timezone=$DB_TIMEZONE \$JAVA_PROPERTIES\"" >> /opt/atsd/atsd/conf/atsd-env.sh
        fi
    }

    function create_account {
        local user=$1
        local pass=$2
        local params=$3
        local description=$4
        if curl -i -s \
            --data-urlencode "userBean.username=$user" \
            --data-urlencode "userBean.password=$pass" \
            --data-urlencode "repeatPassword=$pass" \
            http://127.0.0.1:8088/login${params} | grep -q "$HTTP_FOUND_CODE"; then
            echo "[ATSD] $description account '$user' created." | tee -a  $LOGFILESTART
        else
            echo "[ATSD] Failed to create $description account '$ATSD_COLLECTOR_USER_NAME'." | tee -a  $LOGFILESTART
        fi
    }

    function configure_phantom {
        local property_name="webdriver.phantomjs.path"
        local binary_location="/opt/atsd/phantomjs-2.1.1-linux-x86_64/bin/phantomjs"
        curl -s -u "$ATSD_ADMIN_USER_NAME":"$ATSD_ADMIN_USER_PASSWORD" \
            --data-urlencode "options[0].key=$property_name" \
            --data-urlencode "options[0].value=$binary_location" \
            --data-urlencode "apply=Save" \
            http://127.0.0.1:8088/admin/serverproperties
    }

    function import_files_into_atsd {
        for file_path in ${atsd_import_list}; do
            echo "[ATSD] Importing '$file_path' configuration"
            if curl -i -s -u "$ATSD_ADMIN_USER_NAME:$ATSD_ADMIN_USER_PASSWORD" \
                    -F "files=@$file_path" \
                    -F "autoEnable=on" \
                    http://127.0.0.1:8088/admin/import-backup | grep -q "$HTTP_FOUND_CODE" ; then
                echo "[ATSD] Successfully imported '$file_path'"
            else
                echo "[ATSD] Failed to import '$file_path'"
            fi
        done
    }

    su axibase ${ATSD_ALL} start

    if [ $? -eq 1 ]; then
        echo "[ATSD] Failed to start ATSD. Check $LOGFILESTART file." | tee -a $LOGFILESTART
        exit 1
    fi

    if [ -f "$FIRST_START_MARKER" ]; then
        set_tz
        create_account "$ATSD_COLLECTOR_USER_NAME" "$ATSD_COLLECTOR_USER_PASSWORD" "?type=writer" "Collector"
        create_account "$ATSD_ADMIN_USER_NAME" "$ATSD_ADMIN_USER_PASSWORD" "" "Administrator"
        configure_phantom
        import_files_into_atsd
    fi
}

function start_collector {
    SCRIPTS_HOME="/opt/axibase-collector/bin"

    cd ${SCRIPTS_HOME}
    echo "Starting Axibase Collector ..."

    function validate_docker_socket {
        echo -n "Checking docker socket: ... "
        check_res=$(java -classpath \
            "../exploded/webapp/WEB-INF/classes:../exploded/webapp/WEB-INF/lib/*" \
            com.axibase.collector.util.UnixSocketUtil "$DOCKER_SOCKET" 2>&1);
        if ! [[ -z "$check_res" ]]; then
            if [ "$check_res" == "OK" ]; then
                echo "OK"
            elif [[ "$check_res" == "FAILED"* ]]; then
                echo "$check_res"
            elif [[ "$check_res" == "Unable to read"* ]]; then
                echo "error; $check_res"
                exit 1
            else
                echo
                echo "$check_res"
            fi
        fi
    }

    function start_cron {
        #Create empty cron job
        touch /etc/cron.d/root
        chmod +x /etc/cron.d/root
        printf "# Empty line\n" >> /etc/cron.d/root
        crontab /etc/cron.d/root

        #Start cron
        cron -f &
    }

    function create_collector_account {
        if [ -f "$FIRST_START_MARKER" ]; then
            if curl -i -s --insecure \
                --data-urlencode "user.username=$COLLECTOR_USER_NAME" \
                --data-urlencode "newPassword=$COLLECTOR_USER_PASSWORD" \
                --data-urlencode "confirmedPassword=$COLLECTOR_USER_PASSWORD" \
                --data-urlencode "commit=Save" \
                https://127.0.0.1:9443/register.xhtml | grep -q "$HTTP_FOUND_CODE"; then
                echo "[Collector] Account '$COLLECTOR_USER_NAME' created."
            else
                echo "[Collector] Failed to create account '$COLLECTOR_USER_NAME'."
            fi
        fi
    }

    if [ -e "$DOCKER_SOCKET" ]; then
        validate_docker_socket
        JOB_ENABLE=-job-enable=docker-socket
        collector_execute_arg=$(concat_with "$collector_execute_arg" , docker-socket)
    fi
    start_cron

    if [ -n "$collector_execute_arg" ]; then
        JOB_EXECUTE=-job-execute="$collector_execute_arg"
    fi

    #Start collector
    ./start-collector.sh wait-exec \
        -atsd-url="https://${ATSD_COLLECTOR_USER_NAME}:${ATSD_COLLECTOR_USER_PASSWORD}@localhost:8443" \
        "$JOB_ENABLE" "$JOB_PATH" "$JOB_EXECUTE"

    if [ $? -eq 1 ]; then
        echo "[Collector] Failed to start Collector."
        exit 1
    fi

    create_collector_account
}

function start_collectd {
    echo "Starting collectd ..."
    /usr/sbin/collectd
    COLLECTD_PID=$!
}

function stop_services {
    jps_output=$(jps)

    echo "Stopping collectd ..."
    kill ${COLLECTD_PID}

    echo "Stopping Axibase Collector ..."
    ./stop-collector.sh "-1"

    if echo "${jps_output}" | grep -q "Server"; then
        echo "[ATSD] Stopping ATSD server ..." | tee -a $LOGFILESTOP
        kill -SIGKILL $(echo "${jps_output}" | grep 'Server' | awk '{print $1}') 2>/dev/null
    fi
    echo "[ATSD] Stopping HBase processes ..." | tee -a $LOGFILESTOP
    if echo "${jps_output}" | grep -q "HRegionServer"; then
        ${HBASE_DAEMON} stop regionserver
    fi
    if echo "${jps_output}" | grep -q "HMaster"; then
        ${HBASE_DAEMON} stop master
    fi
    if echo "${jps_output}" | grep -q "HQuorumPeer"; then
        ${HBASE_DAEMON} stop zookeeper
    fi
    echo "[ATSD] ZooKeeper data cleanup ..." | tee -a $LOGFILESTOP
    rm -rf "${ZOOKEEPER_DATA_DIR}" 2>/dev/null
    echo "[ATSD] Stopping HDFS processes ..." | tee -a $LOGFILESTOP
    ${DFS_STOP}

    exit 0
}

function wait_loop {
    executing="true"
    trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
    while [ "$executing" = "true" ]; do
        sleep 1
    done
}

prepare_import
start_atsd
start_collectd
start_collector
if [ -f "$FIRST_START_MARKER" ]; then
    rm "$FIRST_START_MARKER"
fi
echo 'All applications started'
wait_loop
echo "SIGTERM received ( docker stop ). Stopping services ..." | tee -a $LOGFILESTOP
stop_services
