#!/bin/bash

app_instance=__APP__

source /usr/share/yunohost/helpers

coturn_config_path="/etc/matrix-$app_instance/coturn.conf"
public_ip4="$(curl ip.yunohost.org)" || true
public_ip6="$(curl ipv6.yunohost.org)" || true

old_config_line=$(egrep "^external-ip=.*\$" $coturn_config_path)
perl -i -pe 's/(^external-ip=.*\n)*//g' $coturn_config_path

if [ -n "$public_ip4" ] && ynh_validate_ip4 --ip_address="$public_ip4"
then
    echo "external-ip=$public_ip4" >> "$coturn_config_path"
fi

if [ -n "$public_ip6" ] && ynh_validate_ip6 --ip_address="$public_ip6"
then
    echo "external-ip=$public_ip6" >> "$coturn_config_path"
fi

new_config_line=$(egrep "^external-ip=.*\$" "/etc/matrix-$app_instance/coturn.conf")

setfacl -R -m user:turnserver:rX  /etc/matrix-$app_instance

if [ "$old_config_line" != "$new_config_line" ]
then
    systemctl restart coturn-$app_instance.service
fi

exit 0
