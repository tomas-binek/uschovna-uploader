#!/bin/bash

## Write PID to a file and execute arguments

echo $$ > "$1"
shift
"$@"