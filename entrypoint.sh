#!/bin/bash
trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
SCRIPT=$(readlink -f $0)
SCRIPTS_HOME="`dirname $SCRIPT`"
DISTR_HOME="`dirname $SCRIPT`/.."
installUser="${DISTR_HOME}/install_user.sh"
ATSD_ALL="${SCRIPTS_HOME}/atsd-all.sh"
LOGFILESTART="`readlink -f ${DISTR_HOME}/atsd/logs/start.log`"
LOGFILESTOP="`readlink -f ${DISTR_HOME}/atsd/logs/stop.log`"

webUser="${COLLECTOR_USER_NAME}"
webPassword="${COLLECTOR_USER_PASSWORD}"
webType="${COLLECTOR_USER_TYPE-writer}"
if [ -n "$webPassword" ] && [ ${#webPassword} -lt 6 ]; then
    echo "Minimum password length is 6 characters. Your password length is ${#webPassword}. Container will be stopped." | tee -a $LOGFILESTART
    exit 1
fi

#check timezone
if [ -n "$timezone" ]; then
    echo "export JAVA_PROPERTIES=\"-Duser.timezone=$timezone \$JAVA_PROPERTIES\"" >> /opt/atsd/atsd/conf/atsd-env.sh
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
    echo "Can not start atsd automatically. Check $LOGFILESTART file." | tee -a $LOGFILESTART
fi
printf "=====================\nATSD start completed.\n=====================\n" | tee -a $LOGFILESTART

if curl -o - http://127.0.0.1:8088/login?type=writer 2>/dev/null | grep -q "400"; then
    echo "Collector account exists." > /dev/null
elif [ -n $webPassword ] && [ -n $webUser ]; then
    echo "COLLECTOR_USER_NAME or COLLECTOR_USER_PASSWORD are given. Collector account will be created." | tee -a $LOGFILESTART
    if curl -i --data "userBean.username=$webUser&userBean.password=$webPassword&repeatPassword=$webPassword" http://127.0.0.1:8088/login?type=${webType} | grep -q "302"; then
        echo "Collector account with username: $webUser, with usertype: $webType was created." | tee -a  $LOGFILESTART
    else
        echo "Failed to create collector account $webUser . Try to create it manually." | tee -a  $LOGFILESTART
    fi
fi

if [ -n "$login" ] && [ -n "$password" ]; then
    echo "Login and password are given. Admin account will be created." | tee -a $LOGFILESTART
    curl -i --data "userBean.username=$login&userBean.password=$password&repeatPassword=$password" http://127.0.0.1:8088/login
fi

while [ "$executing" = "true" ]; do
    sleep 1
    trap 'echo "kill signal handled, stopping processes ..."; executing="false"' SIGINT SIGTERM
done  
echo "SIGTERM handled ( docker stop ). Stopping services ..." >> $LOGFILESTOP
${ATSD_ALL} stop 
exit 0
