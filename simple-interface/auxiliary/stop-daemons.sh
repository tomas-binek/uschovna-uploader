#!/bin/bash

## Uschovna.cz uploader - Simple interface - Daemon controller


# Load common definitions and functions
source "$(dirname "$BASH_SOURCE")/common.sh"

stopFailWatcher

# Stop uploaders
echo "Stopping uploaders" >&2
while read username _
do
    echo -n " - $username: " >&2
    pidFile="$(uploaderPidFile "$username")"
    
    if [ -f "$pidFile" ]
    then
        pid="$(cat "$pidFile")"
        if kill -0 $pid &>/dev/null
        then
            kill $pid && echo "Stopped" >&2
            rm -f "$pidFile"
        else
            echo "Not running" >&2
        fi
    else
        echo "Not started" >&2
    fi
done < <(getUsersWithUploaderDirectory)