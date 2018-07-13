#!/bin/bash

## Uschovna.cz uploader - Simple interface
##
## Version: 1.0
## Author: Tomáš Binek <tomasbinek@seznam.cz>
#
# This program aims to provide interface to uploading files to uschovna.cz that is as simple as possible
# 
# Design:
# A folder is watched, and each file that is copied there is uploaded to uschovna.cz.
# A new file with link to the package is created.
#
# Procedure:
# Directory is watched using inotifywait.
# On each file that is close after being written to, this is performed:
# - Until finished with this file, have <fileName>.in-progress file present
# - Try to upload the file up to $maximumTries times.
# - When all attempts fail, write <fileName>.failure file with a message and diagnostic data
# - When successful, create <fileName>.url file linking to the newly created package
#
# Output:
# 1 (standard output): Empty
# 2 (standard error output): Various error and reporting messages
# 3: If available, package link and full path to successfully uploaded file is printed after each successfull upload
#    If not available, that line is printed to standard error output, prepended by SUCCESSFULY_UPLOADED
# 4: If available, full path to a file in printed after each failed upload
#    If not available, that line is printed to standard error output, prepended by FAILED_TO_UPLOAD

## Constants

# Uschovna.cz BASH API script
uschovnaczSourceFile="$(dirname "$BASH_SOURCE")/../uschovnacz.sh"

# Maximum number of attempts to upload a file
maximumTries=10

# Sleep between upload attempts
sleepBetweenAttempts=10

# List of necessary commands
dependencies=( inotifywait readlink )

usageText=
read -r -d '' usageText <<END
Uschovna.cz - simple file interface

Usage:
$0 directory

Arguments:
directory: A directory to watch and operate on. Write permission in needed for the directory.
END

## Functions 
function printErrorAndUsage
{
    echo "$@" >&2
    echo >&2
    echo "$usageText" >&2
}

# Print the content of an in-progress file
#
# @uploadStart: A UNIX timestamp of when the file started to be uploaded
#
function printInProgressFile # uploadStart
{
    echo "File upload is in progress since $(date -d "@$processingStartDate")"
}

function printUrlFile # url
{
    echo "[InternetShortcut]"
    echo "URL=$1"
}

function printFailedFile # errorOutputFile
{
    echo "All $maximumTries attempts to upload this file failed."
    echo 
    echo "Below is technical information intended for the system administrator"
    echo ---
    cat "$1"
}

function reportSuccessfulUpload # link file
{
    # Testing whether file descriptor is open
    # https://unix.stackexchange.com/questions/206786/testing-if-a-file-descriptor-is-valid
    if { >&3; } &>/dev/null
    then
        echo "$1 $2" >&3
    else
        echo "SUCCESSFULY_UPLOADED $1 $2" >&2
    fi
}

function reportFailedUpload # file
{
    # Testing whether file descriptor is open
    # https://unix.stackexchange.com/questions/206786/testing-if-a-file-descriptor-is-valid
    if { >&4; } &>/dev/null
    then
        echo "$1" >&4
    else
        echo "FAILED_TO_UPLOAD $1" >&2
    fi
}

# Upload a file 
#
# @fileName: File name inside $baseDirectory
#
# Uses global variables:
# $baseDirectory
# $maximumTries
# $sleepBetweenAttempts
# $skipListFile
#
function uploadFile # fileName
{
    local fileName="$1"
    local inProgressFile="$baseDirectory/$fileName.in-progress"
    local processingStartDate=$(date '+%s')
    local uploadSuccessful=0
    local triesAvailable=$maximumTries
    local packageLink=
    local errorOutputFile="$(mktemp)"
    
    [ -f "$errorOutputFile" ] || { echo "Failed to create temporary file" >&2; return 1; }
    
    echo "$fileName.in-progress" >> "$skipListFile"
    echo "$fileName.failed" >> "$skipListFile"
    echo "$fileName.url" >> "$skipListFile"    
    
    printInProgressFile $processingStartDate > "$inProgressFile"
    trap "rm -rf '$inProgressFile' '$errorOutputFile'" RETURN
    
    # Attempt to upload file, with retries
    while [ $uploadSuccessful = 0 -a $triesAvailable -gt 0 ]
    do
        printf 'Attempt %i of %i\n' $(expr $maximumTries - $triesAvailable + 1) $maximumTries >&2
        (( triesAvailable-- ))
        
        packageLink="$(uschovnaCz_sendPackage '' '' '' "$baseDirectory/$fileName" 2>>"$errorOutputFile")"
        if [ $? = 0 ]
        then
            uploadSuccessful=1
            echo 'Upload successfull' >&2            
            break
        else
            echo 'Upload attempt failed' >&2            
            echo "Waiting $sleepBetweenAttempts" >&2
            sleep $sleepBetweenAttempts
        fi
    done
    
    # Process result of upload
    if [ $uploadSuccessful = 1 ]
    then
        printUrlFile "$packageLink" > "$baseDirectory/$fileName.url"
        reportSuccessfulUpload "$packageLink" "$baseDirectory/$fileName"
    else
        printFailedFile "$errorOutputFile" > "$baseDirectory/$fileName.failed"
        reportFailedUpload "$baseDirectory/$fileName"
    fi
    
    return 0
}

## Runtime variables

# Directory in which we operate
baseDirectory=

# Temporary file holding filenames to skip (.url, .in-progress and .failed files for actual user files)
skipListFile=

## Start of work
echo "Starting" >&2

## Check dependencies
[ ! -r "$uschovnaczSourceFile" ] && echo "File '$uschovnaczSourceFile' does not exist or cannot be read." >&2 && exit 1

for dependency in "${dependencies[@]}"
do
    which "$dependency" &>/dev/null \
    || { echo "Command '$dependency' is needed to run this script." >&2; exit 1; }
done

## Source external files
source "$uschovnaczSourceFile"

## Get arguments
baseDirectoryArgument="$1"
pidFileArgument="$2"

## Check arguments
[ -z "$baseDirectoryArgument"   ] && printErrorAndUsage "Base directory not specified" && exit 1
[ ! -d "$baseDirectoryArgument" ] && printErrorAndUsage "'$baseDirectoryArgument' is not a directory" && exit 1
[ ! -w "$baseDirectoryArgument" ] && printErrorAndUsage "Directory '$baseDirectoryArgument' is not writable" && exit 1

## Use arguments
baseDirectory="$(readlink -f "$baseDirectoryArgument")"

## Prepare
skipListFile=$(mktemp)
trap "rm -f '$skipListFile'" EXIT

## Remove old .in-progress files
( cd "$baseDirectory"; rm -f *.in-progress; )

## Upload files already present, and not having .url or .failed files
while read -r -d '' fileName
do
    fileName="$(basename "$fileName")"
    
    if [ -f "$baseDirectory/$fileName.url" -o -f "$baseDirectory/$fileName.failed" ]
    then
        echo "Continue-operations: Skipping file '$fileName'" >&2
        continue
    else
        echo "Continue-operations: Uploading file '$fileName'" >&2
        uploadFile "$fileName"
    fi
done < <(cd "$baseDirectory"; find . -mindepth 1 '!' -name '*.url' -a '!' -name '*.failed' -print0)

## Start watching and uploading new files
inotifywait --quiet --monitor --event close_write --format '%f' "$baseDirectory" |\
while read fileName
do
    if grep -q -f "$skipListFile" <<< "$fileName"
    then
        echo "Skipping file '$fileName'" >&2
        continue
    fi
    
    echo "Processing file '$fileName'" >&2
    uploadFile "$fileName"    
done
