#!/bin/bash

### BEGIN INIT INFO
# Provides:        uschovna-simple
# Required-Start:  $network
# Required-Stop:
# Default-Start:   2 3 4 5
# Default-Stop: 
# Short-Description: Start daemons that handle Simple uschovna.cz interface for each user in their home folders
### END INIT INFO

case "$1" in
    start)
        bash "$(dirname "$(readlink -f "$BASH_SOURCE")")/start-daemons.sh" 
    ;;
    stop)
        bash "$(dirname "$(readlink -f "$BASH_SOURCE")")/stop-daemons.sh" 
    ;;
esac
