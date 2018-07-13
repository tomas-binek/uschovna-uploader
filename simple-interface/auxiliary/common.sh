#!/bin/bash

## Uschovna.cz uploader - Simple interface - Auxiliary scripts - Common elements
#

uploadDirectoryInHomeDirectory='uschovna.cz/Jednoduché rozhraní'

logDirectory=/var/log/uschovna-uploader/simple
successLogFile=$logDirectory/success.log
failLogFile=$logDirectory/fail.log
stderrLogFile=$logDirectory/stderr.log
failWatcherLogFile=$logDirectory/failwatcher.log

minimumFreeSpaceMB=100

failWatcherPidFile=/var/run/uschovna-uploader-simple-failwatcher.pid
function uploaderPidFile # username
{
    echo "/var/run/uschovna-uploader-simple-for-$1.pid"
}

notificationRecipients='tomasbinek@vodafonemail.cz, tomasbinek@seznam.cz'
notificationSenderName='Uschovna-uploader - Simple interface'

function sendEmailNotification # subject message
{
    local subject="$1"
    local message="$2"
    
    heirloom-mailx -S smtp=smtp.seznam.cz \
                  -S smtp-auth=login \
                  -S smtp-auth-user="ip-notifier@seznam.cz" \
                  -S smtp-auth-password="ipNotifierPassword" \
                  -S from="$notificationSenderName <ip-notifier@seznam.cz>" \
                  -s "$subject" \
                  "$notificationRecipients" \
                  <<< "$message"
}

function stopFailWatcher
{
    if [ -f "$failWatcherPidFile" ]
    then
        pid=$(cat "$failWatcherPidFile")
        if ps -p $pid &>/dev/null
        then
            echo "Stopping failwatcher (pid $pid)" >&2
            kill $pid
            rm -f "$failWatcherPidFile"
        else
            echo "Failwatcher process $pid is not running" >&2
        fi
    else
        echo "Failwatcher pidfile does not exist" >&2
    fi
}

# Prints
# username uploaderDirectory
# for each user that has uploader directory present
#
function getUsersWithUploaderDirectory
{
    local homeDirectory
    local uploadDir
    local username
    
    while read homeDirectory
    do
        uploadDir="$homeDirectory/$uploadDirectoryInHomeDirectory"
        username="$(basename "$homeDirectory")"
        
        if [ -d "$uploadDir" ]
        then
            echo "$username $uploadDir"
        fi
    done < <(find /home -mindepth 1 -maxdepth 1 -type d)
}