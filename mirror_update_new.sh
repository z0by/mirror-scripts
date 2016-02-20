#!/bin/bash

export SRC_MIRR=${1:-Unknown}

TOP_DIR=$(cd $(dirname "$0") && pwd)

CONFIG_FILE="${TOP_DIR}/config.yaml"

source $TOP_DIR/mirror_functions.sh
source $TOP_DIR/functions/locking.sh


INT_LOCATIONS="rsync://osci-mirror-msk.infra.mirantis.net/mirror-sync/mirrors rsync://osci-mirror-srt.infra.mirantis.net/mirror-sync/mirrors rsync://osci-mirror-kha.infra.mirantis.net/mirror-sync/mirrors rsync://osci-mirror-poz.infra.mirantis.net/mirror-sync/mirrors"

function get_mirror_fi_nodes() {
    local POOL_NODES="$(host mirror.fuel-infra.org | awk '/has address/ {print $NF}')"
    local DESTINATIONS="$(URLS=""; for N in ${POOL_NODES}; do URLS+="rsync://${N}/mirror-sync/mirrors "; done; echo ${URLS})"
    echo ${DESTINATIONS}
}

function sync_to_locations() {
    local DESTINATIONS="$@"
    ${WORKSPACE:-.}/trsync/trsync_push.py \
        --init-directory-structure \
        --save-latest-days ${SAVE_LAST_DAYS} \
        ${DST_DIR} \
        ${SRC_MIRR} \
        --timestamp $DATE \
        -d ${DESTINATIONS}
}


eval  $(parse_yaml ${CONFIG_FILE})

flag=false

for mirror in $mirrors; do
    name="${mirror}_name"
    if [ "${!name}" == "$SRC_MIRR" ]
    then
        flag=true
        name="${mirror}_name"
        src="${mirror}_mirrror_source"
        exclude="${mirror}_exclude"
        pre_load="${mirror}_pre_load"
        past_load="${mirror}_past_load"
        if [ -n "${!src}" ]
        then
            export SRC="${!src}"
        fi
        if [ -n "${!exclude}" ]
        then
            export EXCLUDE="${!exclude}"
        fi
        if [ -n "${!pre_load}" ]
        then
            function pre_download() {
                (exec env "${TOP_DIR}"/"${!pre_load}" )
        
            }
        fi
        if [ -n "${!past_load}" ]
        then
            function past_download() {
                (exec env "${TOP_DIR}"/"${!past_load}" )
            }
        fi
        job_lock ${SRC_MIRR}_updates set
        pre_download
        via_$SYNCTYPE
        clear_old_versions
    fi
done

if [ "$flag" = false ]; then
     fatal "Wrong source mirror '$SRC_MIRR'"
fi