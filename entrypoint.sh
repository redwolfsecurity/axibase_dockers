#!/bin/bash
trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
DISTR_HOME="/opt/atsd"
installUser="${DISTR_HOME}/install_user.sh"
ATSD_ALL="${DISTR_HOME}/bin/atsd-all.sh"
HBASE="`readlink -f ${DISTR_HOME}/hbase/bin/hbase`"
HBASE_DAEMON="`readlink -f ${DISTR_HOME}/hbase/bin/hbase-daemon.sh`"
DFS_STOP="`readlink -f ${DISTR_HOME}/hadoop/sbin/stop-dfs.sh`"
LOGFILESTART="`readlink -f ${DISTR_HOME}/atsd/logs/start.log`"
LOGFILESTOP="`readlink -f ${DISTR_HOME}/atsd/logs/stop.log`"
ZOOKEEPER_DATA_DIR="${DISTR_HOME}/hbase/zookeeper"

IMPORT_DIR="/import"
TMP_DOWNLOAD_DIR="/tmp/import-download"

ATSD_ADMIN_USER_NAME=axibase
ATSD_ADMIN_USER_PASSWORD=axibase

ATSD_COLLECTOR_USER_NAME=collector
ATSD_COLLECTOR_USER_PASSWORD=collector

COLLECTOR_USER_NAME=axibase
COLLECTOR_USER_PASSWORD=axibase

collector_import_arg=


function generic_import {
    function import_file_into_atsd {
        local file_path=$1
        curl -s -u "$ATSD_ADMIN_USER_NAME:$ATSD_ADMIN_USER_PASSWORD" \
             -F "files=@$file_path" http://127.0.0.1:8088/admin/import-backup
    }

    function update_collector_argument {
        local import_path=$1
        if [ -n "$collector_import_arg" ]; then
            collector_import_arg="$collector_import_arg",
        fi
        collector_import_arg="$collector_import_arg$import_path"
    }

    local import_spec=$1
    local import_func=$2
    mkdir -p "$IMPORT_DIR"
    mkdir -p "$TMP_DOWNLOAD_DIR"
    for current_path in ${import_spec//,/ }; do
        local import_path
        echo "Importing $current_path"
        if [[ "$current_path" =~ (ftp|https?)://.* ]]; then
            wget -P "$TMP_DOWNLOAD_DIR" "$current_path"
            local file_name=$(ls -1 "$TMP_DOWNLOAD_DIR")
            import_path="$IMPORT_DIR"/${file_name%\?*}
            mv "$TMP_DOWNLOAD_DIR"/"$file_name" "$import_path"
        else
            import_path="$IMPORT_DIR"/"$current_path"
        fi
        ${import_func} "$import_path"
    done
    rm -rf "$TMP_DOWNLOAD_DIR"
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
        if curl -i -s --data "userBean.username=$user&userBean.password=$pass&repeatPassword=$pass" \
            http://127.0.0.1:8088/login${params} | grep -q "302"; then
            echo "[ATSD] $description account '$user' created." | tee -a  $LOGFILESTART
        else
            echo "[ATSD] Failed to create $description account '$ATSD_COLLECTOR_USER_NAME'." | tee -a  $LOGFILESTART
        fi
    }

    function configure_phantom {
        curl -s -u "$ATSD_ADMIN_USER_NAME":"$ATSD_ADMIN_USER_PASSWORD" --data \
            "options%5B0%5D.key=webdriver.phantomjs.path&options%5B0%5D.value=%2Fopt%2Fatsd%2Fphantomjs-2.1.1-linux-x86_64%2Fbin%2Fphantomjs&apply=Save" \
            http://127.0.0.1:8088/admin/serverproperties
    }

    su axibase ${ATSD_ALL} start

    if [ $? -eq 1 ]; then
        echo "[ATSD] Failed to start ATSD. Check $LOGFILESTART file." | tee -a $LOGFILESTART
    fi

    if [ -f /first-start ]; then
        set_tz
        create_account "$ATSD_COLLECTOR_USER_NAME" "$ATSD_COLLECTOR_USER_PASSWORD" "?type=writer" "Collector"
        create_account "$ATSD_ADMIN_USER_NAME" "$ATSD_ADMIN_USER_PASSWORD" "" "Administrator"
        configure_phantom
        generic_import "$ATSD_IMPORT_PATH" import_file_into_atsd
    fi
}

function start_collector {
    SCRIPTS_HOME="/opt/axibase-collector/bin"

    cd ${SCRIPTS_HOME}
    echo "Starting Axibase Collector ..."

    function print_error {
        echo "Error: $1"
    }

    function validate_docker_socket {
        echo -n "Checking docker socket..."
        if [ ! -e "/var/run/docker.sock" ]; then
            print_error "Docker socket /var/run/docker.sock is not mounted"
            exit 1
        fi
        check_res=`java -classpath "../exploded/webapp/WEB-INF/classes:../exploded/webapp/WEB-INF/lib/*" com.axibase.collector.util.UnixSocketUtil /var/run/docker.sock 2>&1`;
        if ! [[ -z "$check_res" ]]; then
            if [ "$check_res" == "OK" ]; then
                echo "OK"
            elif [[ "$check_res" == "FAILED"* ]]; then
                echo "$check_res"
            elif [[ "$check_res" == "Unable to read"* ]]; then
                echo
                print_error "$check_res"
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

    function update_import_configs {
        if [ -n "$EDIT_CONFIGS" ]; then
            local edits="${EDIT_CONFIGS//;/ }"
            for edit in ${edits}; do
                local parameter_edits=(${edit//,/ })
                local file_to_edit=${parameter_edits[@]:0:1}
                echo "Updating file $file_to_edit for import"
                for param_edit in ${parameter_edits[@]:1}; do
                    local key=${param_edit%=*}
                    local value=${param_edit#*=}
                    sed -i "/$key/s/>.*</>$value</" "$IMPORT_DIR"/"$file_to_edit"
                    if [ "$key" = password ]; then
                        sed -i "s/<password>/<password encrypted=\"false\">/" "$IMPORT_DIR"/"$file_to_edit"
                    fi
                done
            done
        fi
    }

    function create_collector_account {
        if [ -f /first-start ]; then
            if curl -i -s --insecure --data \
                "user.username=$COLLECTOR_USER_NAME&newPassword=$COLLECTOR_USER_PASSWORD&confirmedPassword=$COLLECTOR_USER_PASSWORD&commit=Save" \
                https://127.0.0.1:9443/register.xhtml | grep -q "302"; then
                echo "[Collector] Account '$COLLECTOR_USER_NAME' created." | tee -a  $LOGFILESTART
            else
                echo "[Collector] Failed to create account '$COLLECTOR_USER_NAME'." | tee -a  $LOGFILESTART
            fi
        fi
    }

    validate_docker_socket
    start_cron
    if [ -f /first-start ] && [ -n "$COLLECTOR_IMPORT_PATH" ]; then
        generic_import "$COLLECTOR_IMPORT_PATH" update_collector_argument
        JOB_PATH=-job-path="$collector_import_arg"
    fi
    update_import_configs
    #Start collector
    ./start-collector.sh \
        -atsd-url="https://${ATSD_COLLECTOR_USER_NAME}:${ATSD_COLLECTOR_USER_PASSWORD}@localhost:8443" \
        -job-enable=docker-socket \
        "$JOB_PATH"
    create_collector_account
}

function start_collectd {
    echo "Starting collectd ..."
    /usr/sbin/collectd > /dev/null
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

start_atsd
start_collector
start_collectd
if [ -f /first-start ]; then
    rm /first-start
fi
echo 'All applications started'
wait_loop
echo "SIGTERM received ( docker stop ). Stopping services ..." | tee -a $LOGFILESTOP
stop_services
