#!/bin/bash

## Uschovna.cz uploader - Simple interface - Daemon controller

uploaderScript="$(dirname "$BASH_SOURCE")/../simple-uploader.sh"
failwatcherScript="$(dirname "$BASH_SOURCE")/failwatcher.sh"

# Load common definitions and functions
source "$(dirname "$BASH_SOURCE")/common.sh"

function prependDateAndUser # username
{
    local l
    while read l
    do
        echo "$(date '+%Y-%m-%d·%H:%M:%S') $1 $l"
    done
}
    
function startUploaderFor # username directory
{
    local pidFile="$(uploaderPidFile "$1")"
    
    # Start the uploader
    nohup su "$1" -c "bash '$uploaderScript' '$2'" \
    0< /dev/null \
    1> /dev/null \
    2> >(prependDateAndUser "$1" >> "$stderrLogFile") \
    3> >(prependDateAndUser "$1" >> "$successLogFile") \
    4> >(prependDateAndUser "$1" >> "$failLogFile") \
    &
    echo $! > "$pidFile"
}

# Stop previous failwatcher, if exists
stopFailWatcher

# Start failwatcher
echo "Starting FailWatcher" >&2
nohup su -c "bash '$failwatcherScript'" 1>/dev/null 2>>"$failWatcherLogFile" & # Su is used to handle killing subprocesses on exit
echo $! > "$failWatcherPidFile"

# Start uploaders
echo "Starting uploaders" >&2
while read username uploadDir
do
    echo " - $username" >&2
    startUploaderFor "$username" "$uploadDir"
done < <(getUsersWithUploaderDirectory)