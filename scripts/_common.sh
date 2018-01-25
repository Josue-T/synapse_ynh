#!/bin/bash

# Retrieve arguments
app=$YNH_APP_INSTANCE_NAME
synapse_user="matrix-$app"
synapse_db_name="matrix_$app"
synapse_db_user="matrix_$app"
upstream_version=$(ynh_app_upstream_version)

install_dependances() {
	ynh_install_app_dependencies coturn build-essential python2.7-dev libffi-dev python-pip python-setuptools sqlite3 libssl-dev python-virtualenv libxml2-dev libxslt1-dev python-lxml libjpeg-dev libpq-dev postgresql acl
	pip install --upgrade pip
	pip install --upgrade virtualenv
}

setup_dir() {
    # Create empty dir for synapse
    mkdir -p /var/lib/matrix-$app
    mkdir -p /var/log/matrix-$app
    mkdir -p /etc/matrix-$app/conf.d
    mkdir -p $final_path
}

set_permission() {
    # Set permission
    chown $synapse_user:root -R $final_path
    chown $synapse_user:root -R /var/lib/matrix-$app
    chown $synapse_user:root -R /var/log/matrix-$app
    chown $synapse_user:root -R /etc/matrix-$app
    chmod 600 /etc/matrix-$app/dh.pem
    setfacl -R -m user:turnserver:rx  /etc/matrix-$app
    setfacl -R -m user:turnserver:rwx  /var/log/matrix-$app
}

install_source() {
	if [ -n "$(uname -m | grep arm)" ]
	then
		ynh_setup_source $final_path/ "armv7"
	else
		# Install virtualenv if it don't exist
		test -e $final_path/bin || virtualenv -p python2.7 $final_path

		# Install synapse in virtualenv
		PS1=""
		cp ../conf/virtualenv_activate $final_path/bin/activate
		ynh_replace_string __FINAL_PATH__ $final_path $final_path/bin/activate
		source $final_path/bin/activate
		pip install --upgrade pip
		pip install --upgrade setuptools
		pip install --upgrade cffi ndg-httpsclient psycopg2 lxml
		pip install --upgrade https://github.com/matrix-org/synapse/archive/v$upstream_version.tar.gz
		
		# Fix issue with msgpack see https://github.com/YunoHost-Apps/synapse_ynh/issues/29
		test -e $final_path/lib/python2.7/site-packages/msgpack/__init__.py || (\
                pip uninstall -y msgpack-python msgpack; \
                pip install msgpack-python)
		
		deactivate
	fi
}

config_synapse() {
	ynh_backup_if_checksum_is_different /etc/matrix-$app/homeserver.yaml
	ynh_backup_if_checksum_is_different /etc/matrix-$app/log.yaml
	cp ../conf/homeserver.yaml /etc/matrix-$app/homeserver.yaml
	cp ../conf/log.yaml /etc/matrix-$app/log.yaml
	
	ynh_replace_string __APP__ $app /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __DOMAIN__ $domain /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __SYNAPSE_DB_USER__ $synapse_db_user /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __SYNAPSE_DB_PWD__ $synapse_db_pwd /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __PORT__ $port /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __TLS_PORT__ $synapse_tls_port /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __TURNSERVER_TLS_PORT__ $turnserver_tls_port /etc/matrix-$app/homeserver.yaml
	ynh_replace_string __TURNPWD__ $turnserver_pwd /etc/matrix-$app/homeserver.yaml
	
	ynh_replace_string __APP__ $app /etc/matrix-$app/log.yaml

	if [ "$is_public" = "0" ]
	then
		ynh_replace_string __ALLOWED_ACCESS__ False /etc/matrix-$app/homeserver.yaml
	else
		ynh_replace_string __ALLOWED_ACCESS__ True /etc/matrix-$app/homeserver.yaml
	fi
	
    ynh_store_file_checksum /etc/matrix-$app/homeserver.yaml
	ynh_store_file_checksum /etc/matrix-$app/log.yaml
}

config_coturn() {
	ynh_backup_if_checksum_is_different /etc/matrix-$app/coturn.conf
	cp ../conf/turnserver.conf /etc/matrix-$app/coturn.conf
	
	ynh_replace_string __APP__ $app /etc/matrix-$app/coturn.conf
	ynh_replace_string __TURNPWD__ $turnserver_pwd /etc/matrix-$app/coturn.conf
	ynh_replace_string __DOMAIN__ $domain /etc/matrix-$app/coturn.conf
	ynh_replace_string __TLS_PORT__ $turnserver_tls_port /etc/matrix-$app/coturn.conf
	ynh_replace_string __TLS_ALT_PORT__ $turnserver_alt_tls_port /etc/matrix-$app/coturn.conf
	ynh_replace_string __CLI_PORT__ $cli_port /etc/matrix-$app/coturn.conf
	
	ynh_store_file_checksum /etc/matrix-$app/coturn.conf
}