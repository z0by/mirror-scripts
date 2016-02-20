#!/bin/bash

reposync -c $TOP_DIR/spacewalk.conf -l -m -d --download_path=/media/mirrors/yum_update/ || fatal "reposync failed"
createrepo /media/mirrors/yum_update/spacewalk/ || fatal "createrepo failed"
