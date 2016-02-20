#!/bin/bash

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