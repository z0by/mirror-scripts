  reposync -c $TOP_DIR/zabbix.conf -l -m -d --download_path=/media/mirrors/yum_update/ || fatal "reposync failed"
            createrepo /media/mirrors/yum_update/zabbix/ || fatal "createrepo failed"
