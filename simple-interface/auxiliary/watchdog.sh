#!/bin/bash

## Uschovna.cz uploader - Simple interface - Watchdog
#
# Checks whether
# - Uploaders are running
# - Failwatcher is running
# - There is enough space for logs
#
# Also gzips logs (replaceable by logrotate)
#
# Should be run periodically (e.g. using cron)
#

# Load common definitions and functions
source "$(dirname "$(readlink -f "$BASH_SOURCE")")/common.sh"

# Check free space
echo -n "Free space: "
freeSpace=$(df --output=avail --block-size 1MB "$logDirectory" |tail -n 1)
if [ $freeSpace -gt $minimumFreeSpaceMB ]
then
    echo "OK"
else
    echo "Alert - $freeSpace MB left"
    sendEmailNotification "Free space is drawing out" "There is $freeSpace MB available in $logDirectory"
fi

# Check failwatcher
echo -n "Failwatcher: "
if [ ! -f "$failWatcherPidFile" ]
then
    echo "Not started"
elif ! ps -p $(cat "$failWatcherPidFile") &>/dev/null
then
    echo "Not running"
    sendEmailNotification "Failwatcher is not running" ""
else
    echo "OK"
fi

# Check uploaders
echo "Uploaders:"
while read username _
do
    echo -n " - $username: " >&2
    pidFile="$(uploaderPidFile "$username")"
    
    if [ ! -f "$pidFile" ]
    then
        echo "Not started"
    elif ! kill -0 $(cat "$pidFile") &>/dev/null
    then 
        echo "Not running"; 
        sendEmailNotification "Uploader for $username is not running" "Pidfile is present, but the process is gone"
    else
        echo "OK"
    fi
done < <(getUsersWithUploaderDirectory)

echo $(date) > /tmp/watchdog-was-executed