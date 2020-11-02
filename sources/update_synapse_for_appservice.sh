#!/bin/bash

app=__APP__
service_config_file=/etc/matrix-$app/conf.d/app_service.yaml

# Backup the previous config file
cp $service_config_file /tmp/app_service_backup.yaml

echo "app_service_config_files:" > $service_config_file
for f in $(ls /etc/matrix-$app/app-service/); do
    echo "  - /etc/matrix-$app/app-service/$f" >> $service_config_file
    chmod 600 /etc/matrix-$app/app-service/$f
done

# Set permissions
chown --reference=$service_config_file -R /etc/matrix-$app 
chmod 600 $service_config_file

systemctl restart matrix-$app

if [ $? -eq 0 ]; then
    rm /tmp/app_service_backup.yaml
    exit 0
else
    echo "Failed to restart synapse with the new config file. Restore the old config file !!"
    mv /tmp/app_service_backup.yaml $service_config_file
fi
