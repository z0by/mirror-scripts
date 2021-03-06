#!/bin/bash -x

export SRC_MIRR=${1:-Unknown}

TOP_DIR=$(cd $(dirname "$0") && pwd)
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

case "$SRC_MIRR" in
    "mos-ubuntu")
        export SRC="rsync://obs-1.mirantis.com/mos-ubuntu/"
        ;;
    "mos-centos-6")
        export SRC="rsync://obs-1.mirantis.com/mos-centos-6/"
        ;;
    "ubuntu")
        export SRC="rsync://mirrors.msk.mirantis.net/mirrors/${SRC_MIRR}/"
        function past_download() {
            date -u > $DST_DIR/project/trace/$(hostname -f)
        }
        #export EXCLUDE="--exclude \"Packages*\" --exclude \"Sources*\" --exclude \"Release*\""
        ;;
    "centos")
        export SRC="rsync://mirrors.msk.mirantis.net/mirrors/${SRC_MIRR}/"
        #export EXCLUDE="--exclude \"local*\" --exclude \"isos\""
        ;;
    "docker")
        export SRC="rsync://mirror.yandex.ru/mirrors/${SRC_MIRR}/"
        export EXCLUDE='--exclude .temp --exclude .lastsync --exclude .mirror.yandex.ru'
        function past_download() {
            sync_to_locations $(get_mirror_fi_nodes) ${INT_LOCATIONS}
        }
        ;;
    "jenkins")
        export SRC="rsync://mirror.yandex.ru/mirrors/jenkins/debian-stable"
        function past_download() {
            # Based on the method described here:
            # http://troubleshootingrange.blogspot.com/2012/09/hosting-simple-apt-repository-on-centos.html

            pushd $LATEST/debian-stable
                dpkg-scanpackages -m . > Packages
                gzip -9c Packages > Packages.gz

                # Generate release file
                cat > Release <<ENDRELEASE
Architectures: all
Date: $(date -Ru)
Origin: jenkins-ci.org
Suite: debian-stable
ENDRELEASE

                # Generate hashes
                c1=(MD5Sum: SHA1: SHA256: SHA512:)
                c2=(md5 sha1 sha256 sha512)

                i=0
                while [ $i -lt ${#c1[*]} ]; do
                    echo ${c1[i]} >> Release
                    for hashme in `find . -type f \( -name "Package*" -o -name "Release*" \)`; do
                        chash=`openssl dgst -${c2[$i]} ${hashme}|cut -d" " -f 2`
                        size=`stat -c %s ${hashme}`
                        echo " ${chash} ${size} $(basename ${hashme})" >> Release
                    done
                    i=$(( $i + 1));
                done
                gpg --yes --armor -o Release.gpg -sb Release

            popd
            gpg --export -a product@mirantis.com > $LATEST/product.mirantis.com.gpg.key

            sync_to_locations $(get_mirror_fi_nodes) ${INT_LOCATIONS}
        }
        ;;
    "elasticsearch")
        export SRC="/media/mirrors/mirror_update/mirror/packages.elasticsearch.org/elasticsearch/1.3"
        function pre_download() {
            apt-mirror || fatal "apt-mirror failed"
        }
        function past_download() {
            sync_to_locations ${INT_LOCATIONS}
        }
        ;;
    "epel")
        export SRC="rsync://mirror.yandex.ru/fedora-epel"
        export EXCLUDE='--exclude=i386 --exclude=ppc* --exclude=4* --exclude=5* --exclude=7* --exclude=testing'
        ;;
    "jpackage")
        export SRC="rsync://ftp.heanet.ie/pub/jpackage/5.0"
        export EXCLUDE='--exclude=fedora* --exclude=redhat-el*'
        ;;
    "spacewalk")
        export SRC="/media/mirrors/yum_update/spacewalk"
        function pre_download() {
            reposync -c $TOP_DIR/spacewalk.conf -l -m -d --download_path=/media/mirrors/yum_update/ || fatal "reposync failed"
            createrepo /media/mirrors/yum_update/spacewalk/ || fatal "createrepo failed"
        }
        ;;
    "zabbix")
        export SRC="/media/mirrors/yum_update/zabbix"
        function pre_download() {
            reposync -c $TOP_DIR/zabbix.conf -l -m -d --download_path=/media/mirrors/yum_update/ || fatal "reposync failed"
            createrepo /media/mirrors/yum_update/zabbix/ || fatal "createrepo failed"
        }
        ;;
    *)
        fatal "Wrong source mirror '$SRC_MIRR'"
esac

job_lock ${SRC_MIRR}_updates set
pre_download
via_$SYNCTYPE
clear_old_versions
