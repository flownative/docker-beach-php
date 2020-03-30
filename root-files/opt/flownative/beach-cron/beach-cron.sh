#!/bin/bash

while true; do
    info "Beach: Started cron-job loop"
    currentMinute=$(date +"%M")
    if [ "${currentMinute}" == "15" ] && [[ -f "/application/beach-cron-hourly.sh" ]]; then
        mkdir -p /application/Data/Logs/
        chmod 775 /application/beach-cron-hourly.sh
        /application/beach-cron-hourly.sh >> /application/Data/Logs/BeachCron.log 2>&1
        sleep 10
    fi
    sleep 55
done
