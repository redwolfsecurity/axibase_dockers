#!/bin/bash
trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
SCRIPT=$(readlink -f $0)
SCRIPTS_HOME="`dirname $SCRIPT`"
DISTR_HOME="`dirname $SCRIPT`/.."
installUser="${DISTR_HOME}/install_user.sh"
ATSD_ALL="${SCRIPTS_HOME}/atsd-all.sh"
LOGFILESTART="`readlink -f ${DISTR_HOME}/atsd/logs/start.log`"
LOGFILESTOP="`readlink -f ${DISTR_HOME}/atsd/logs/stop.log`"

collectorUser="${COLLECTOR_USER_NAME}"
collectorPassword="${COLLECTOR_USER_PASSWORD}"
collectorType="${COLLECTOR_USER_TYPE-writer}"

if [ -n "$collectorPassword" ] && [ ${#collectorPassword} -lt 6 ]; then
    echo "Minimum password length for collector account is 6 characters. Container start aborted." | tee -a $LOGFILESTART
    exit 1
fi

if [ -n "$ADMIN_USER_PASSWORD" ] && [ ${#ADMIN_USER_PASSWORD} -lt 6 ]; then
    echo "Minimum password length for administrator account is 6 characters. Container start aborted." | tee -a $LOGFILESTART
    exit 1
fi

# set custom timezone
if [ -n "$DB_TIMEZONE" ]; then
    echo "export JAVA_PROPERTIES=\"-Duser.timezone=$DB_TIMEZONE \$JAVA_PROPERTIES\"" >> /opt/atsd/atsd/conf/atsd-env.sh
fi

directoriesToCheck="hdfs-cache hdfs-data hdfs-data-name"
firstStart="true"
executing="true"

for directory in $directoriesToCheck; do
    if ! find  ${DISTR_HOME}/$directory -depth -type d -empty | grep ".*" >/dev/null 2>&1; then
        firstStart="false"
    fi
done

if [ "$firstStart" = "true" ]; then
    $installUser
else
    ${ATSD_ALL} start
fi

if [ $? -eq 1 ]; then
    echo "Failed to start ATSD. Check $LOGFILESTART file." | tee -a $LOGFILESTART
fi

printf "=====================\nATSD start completed.\n=====================\n" | tee -a $LOGFILESTART

if curl -o - http://127.0.0.1:8088/login?type=writer 2>/dev/null | grep -q "400"; then
    echo "Collector account already exists." > /dev/null
elif [ -n "$collectorPassword" ] && [ -n "$collectorUser" ]; then
    echo "Collector username and password variables are set. Collector account will be created." | tee -a $LOGFILESTART
    if curl -s -i --data "userBean.username=$collectorUser&userBean.password=$collectorPassword&repeatPassword=$collectorPassword" http://127.0.0.1:8088/login?type=${collectorType} | grep -q "302"; then
        echo "Collector account with username: $collectorUser, with usertype: $collectorType was created." | tee -a  $LOGFILESTART
    else
        echo "Failed to create collector account $collectorUser." | tee -a  $LOGFILESTART
    fi
fi

if [ -n "$ADMIN_USER_NAME" ] && [ -n "$ADMIN_USER_PASSWORD" ]; then
    echo "Administrator username and password variables are set. Administrator account will be created." | tee -a $LOGFILESTART
    if curl -s -i --data "userBean.username=$ADMIN_USER_NAME&userBean.password=$ADMIN_USER_PASSWORD&repeatPassword=$ADMIN_USER_PASSWORD" http://127.0.0.1:8088/login | grep -q "302"; then
        echo "Administrator account with username: $ADMIN_USER_NAME was created." | tee -a  $LOGFILESTART
    else
        echo "Failed to create administrator account $ADMIN_USER_NAME." | tee -a  $LOGFILESTART
    fi
fi

while [ "$executing" = "true" ]; do
    sleep 1
    trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
done  
echo "SIGTERM handled ( docker stop ). Stopping services ..." >> $LOGFILESTOP
${ATSD_ALL} stop 
exit 0
