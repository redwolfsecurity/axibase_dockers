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

ATSD_USER_NAME=axibase
ATSD_USER_PASSWORD=axibase

function start_atsd {
    su axibase ${ATSD_ALL} start

    if [ $? -eq 1 ]; then
        echo "[ATSD] Failed to start ATSD. Check $LOGFILESTART file." | tee -a $LOGFILESTART
    fi

    if [ -f /first ]; then
        rm /first

        # set custom timezone
        if [ -n "$DB_TIMEZONE" ]; then
            echo "[ATSD] Database timezone set to '$DB_TIMEZONE'." | tee -a  $LOGFILESTART
            echo "export JAVA_PROPERTIES=\"-Duser.timezone=$DB_TIMEZONE \$JAVA_PROPERTIES\"" >> /opt/atsd/atsd/conf/atsd-env.sh
        fi

        if curl -s -i --data "userBean.username=$ATSD_USER_NAME&userBean.password=$ATSD_USER_PASSWORD&repeatPassword=$ATSD_USER_PASSWORD" \
            http://127.0.0.1:8088/login | grep -q "302"; then
            echo "[ATSD] Administrator account '$ATSD_USER_NAME' created." | tee -a  $LOGFILESTART
        else
            echo "[ATSD] Failed to create administrator account '$ATSD_USER_NAME'." | tee -a  $LOGFILESTART
        fi
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

    validate_docker_socket


    #Create empty cron job
    touch /etc/cron.d/root
    chmod +x /etc/cron.d/root
    printf "# Empty line\n" >> /etc/cron.d/root
    crontab /etc/cron.d/root

    #Start cron
    cron -f &

    #Start collector
    ./start-collector.sh -atsd-url="https://${ATSD_USER_NAME}:${ATSD_USER_PASSWORD}@localhost:8443" -job-enable=docker-socket
}

function stop_services {
    jps_output=$(jps)

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
wait_loop
echo "SIGTERM received ( docker stop ). Stopping services ..." | tee -a $LOGFILESTOP
stop_services
