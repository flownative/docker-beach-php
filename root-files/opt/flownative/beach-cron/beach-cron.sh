#!/bin/bash

while true; do
    currentMinute=$(date +"%M")
    if [ "${currentMinute}" == "15" ] && [[ -f "${BEACH_APPLICATION_PATH}/beach-cron-hourly.sh" ]]; then
        mkdir -p ${BEACH_APPLICATION_PATH}/Data/Logs/
        chmod 775 ${BEACH_APPLICATION_PATH}/beach-cron-hourly.sh
        ${BEACH_APPLICATION_PATH}beach-cron-hourly.sh >> ${BEACH_APPLICATION_PATH}/Data/Logs/BeachCron.log 2>&1
        sleep 10
    fi
    sleep 55
done
