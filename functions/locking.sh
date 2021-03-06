#!/bin/bash -xe

export LANG=C

function exit_with_error() {
    echo "$@"
    exit 1
}

function job_lock() {
    [ -z "$1" ] && exit_with_error "Lock file is not specified"
    local LOCKFILE=/tmp/$1
    shift
    fd=15
    eval "exec $fd>$LOCKFILE"
    case $1 in
        "set")
            flock -x -n $fd \
                || exit_with_error "Process already running. Lockfile: $LOCKFILE"
            ;;
        "unset")
            flock -u $fd
            ;;
        "wait")
            TIMEOUT=${2:-3600}
            echo "Waiting of concurrent process (lockfile: $LOCKFILE, timeout = $TIMEOUT seconds) ..."
            flock -x -w $TIMEOUT $fd \
                && echo DONE \
                || exit_with_error "Timeout error (lockfile: $LOCKFILE)"
            ;;
    esac
}

