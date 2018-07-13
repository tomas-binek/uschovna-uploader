#!/bin/bash

## Uschovna.cz uploader - Simple interface - Failwatcher
#
# Watches failed uploads and sends notifications
#

# Load common definitions and functions
source "$(dirname "$BASH_SOURCE")/common.sh"

# Check environment
[ ! -f "$failLogFile" ] && { echo "Fail log '$failLogFile' does not exist" >&2; exit 1; }

# Watch and notify
while read failLine
do
    sendEmailNotification "Failed upload" "$failLine" \
    || echo "Unable to send notification email" >&2
done < <(tail -f -n 0 "$failLogFile")