#!/bin/bash

## Uschovna.cz BASH programmatic API
##
## Author: Tomáš Binek <tomasbinek@seznam.cz>
## Version: 1.2


uschovnaCz_baseUrl="http://www.uschovna.cz"
uschovnaCz_uploadFormUrl="$uschovnaCz_baseUrl/poslat-zasilku"

# Send package
#
# Parameters:
# 1. senderEmail, may be empty
# 2. recipientEmails, may be empty, emails separated by comas, spaces around comas are stripped
# 3. message, may be empty, may be multiline
# 4. file(s), one file per argument, at least one file must be present
#
# Outputs link to the package
#
function uschovnaCz_sendPackage # senderEmail recipientEmails message file(s)...
{
    local senderEmail="$1"
    local recipientEmails="$2"
    local message="$3"
    shift 3
    local -a files=("$@")
    local file
    
    # Check input files
    for file in "${files[@]}"
    do 
        [ -r "$file" ] || { echo "File '$file' is not readable" >&2; return 1; }
    done

    local uploadUrl="" # Will be constructed

    local targetOfFormFile="$(mktemp)"
    local messageFile="$(mktemp)"
    local errorOutputFile="$(mktemp)"
    local standardOutputFile="$(mktemp)"
    
    [ -f "$targetOfFormFile" -a -f "$messageFile" -a -f "$errorOutputFile" -a -f "$standardOutputFile" ] \
    || { echo ERROR "Temporary files were not created" >&2; return 1; }
    
    trap "rm -f '$targetOfFormFile' '$messageFile' '$errorOutputFile' '$errorOutputFile'" RETURN

    # Convert recipient emails to array
    IFS=',' read -r -a recipientEmails <<< "$(tr -d ' ' <<< "$recipientEmails")"
    # Not checking email validity

    # Download form page
    wget "$uschovnaCz_uploadFormUrl" -O "$targetOfFormFile" 1>"$standardOutputFile" 2>"$errorOutputFile" \
    || { 
        echo ERROR "Getting '$uschovnaCz_uploadFormUrl' failed" >&2
        echo "Wget stdout:" >&2
        cat "$standardOutputFile" >&2
        echo >&2
        echo "Wget stderr:" >&2
        cat "$errorOutputFile" >&2
        return 1
    }

    # Verify we are able to extract target from page
    local targetRegExp='[[:space:]]*<form id="upload_form" action="(/uploaded/[0-9]+/)"[^>]+>'
    egrep -q "$targetRegExp" < "$targetOfFormFile" \
    || { 
        echo ERROR "Unable to extract upload target from '$uschovnaCz_uploadFormUrl' using regular expression $targetRegExp" >&2
        echo "Content downloaded from abovementioned url:" >&2
        cat "$targetOfFormFile" >&2
        return 2
    }

    # Extract form target from page and construct upload URL
    local targetOfForm="$(sed -nre "s|$targetRegExp|\1|p" < "$targetOfFormFile")"
    uploadUrl="${uschovnaCz_baseUrl}${targetOfForm}"
    [ -n "$uploadUrl" ] || { echo ERROR "Unable to parse upload url using sed. This is weird." >&2; return 2; }
    # echo DEBUG "Will upload to '$uploadUrl'" >&2

    # Save message to file (because of newlines in it)
    echo "$message" > "$messageFile" \
    || { echo ERROR "Unable to save message to temporary file '$messageFile'" >&2; return 3; }

    # Construct upload command
    local recipientEmail
    local uploadCommand="curl"
    uploadCommand="$uploadCommand --form 'sender_mail=$senderEmail'"
    for recipientEmail in "${recipientEmails[@]}"
    do
        uploadCommand="$uploadCommand --form 'prijemci[]=$recipientEmail'"
    done
    uploadCommand="$uploadCommand --form 'message=<$messageFile'"
    for file in "${files[@]}"
    do
        uploadCommand="$uploadCommand --form 'f[]=@$file'"
    done
    uploadCommand="$uploadCommand '$uploadUrl'"

    # Debug info
    # echo INFO "Sending ${#files[@]} files, from $senderEmail,to ${recipientEmails[@]}, message: $message" >&2
    # echo DEBUG "Command: $uploadCommand" >&2
    
    # Send
    eval "$uploadCommand" 1>"$standardOutputFile" 2>"$errorOutputFile" \
    || {
        echo ERROR "Failed to upload" >&2
        echo "The command: $uploadCommand" >&2
        echo "Curl standard output (the recieved data):" >&2
        cat "$standardOutputFile" >&2
        echo >&2
        echo "Curl error output:" >&2
        cat "$errorOutputFile" >&2        
        return 4
    }

    # Parse curl output to get package id
    local packageId="$(cat "$standardOutputFile" |sed -nre "s/^[^(]+\('([^']+)'\).*/\1/p" |tr -d ' ')"
    [ -n "$packageId" ] && grep -q '-' <<< "$packageId" \
    || {
        echo ERROR "Failed to parse package id from server response" >&2
        echo ERROR "Recieved content:" >&2
        cat "$standardOutputFile" >&2
        echo >&2
        echo "Curl error output:" >&2
        cat "$errorOutputFile" >&2        
        return 4
    }

    # Print link to package
    echo "$uschovnaCz_baseUrl/zasilka/$packageId"
}
