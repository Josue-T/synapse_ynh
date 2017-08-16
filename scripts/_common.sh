#!/bin/bash

# Retrieve arguments
app=$YNH_APP_INSTANCE_NAME
synapse_user="matrix-synapse"
synapse_db_name="matrix_synapse"
synapse_db_user="matrix_synapse"
synapse_version="0.22.0"

install_dependances() {
	ynh_install_app_dependencies coturn build-essential python2.7-dev libffi-dev python-pip python-setuptools sqlite3 libssl-dev python-virtualenv libjpeg-dev libpq-dev postgresql
	pip install --upgrade pip
	pip install --upgrade cffi
	pip install --upgrade ndg-httpsclient
	pip install --upgrade virtualenv
}

install_from_source() {
    # Create empty dir for synapse
    mkdir -p /var/lib/matrix-synapse
    mkdir -p /var/log/matrix-synapse
    mkdir -p /etc/matrix-synapse/conf.d
    mkdir -p $final_path

    # Install synapse in virtualenv
    virtualenv -p python2.7 $final_path
    PS1=""
    cp ../conf/virtualenv_activate $final_path/bin/activate
    source $final_path/bin/activate
    pip install --upgrade pip
    pip install --upgrade setuptools
    pip install https://github.com/matrix-org/synapse/tarball/master
    pip install psycopg2
    
    # Set permission
    chown $synapse_user:root -R $final_path
    chown $synapse_user:root -R /var/lib/matrix-synapse
    chown $synapse_user:root -R /var/log/matrix-synapse
    chown $synapse_user:root -R /etc/matrix-synapse
}

config_nginx() {
	cp ../conf/nginx.conf /etc/nginx/conf.d/$domain.d/$app.conf

	ynh_replace_string __PATH__ $path /etc/nginx/conf.d/$domain.d/$app.conf
	ynh_replace_string __PORT__ $synapse_port /etc/nginx/conf.d/$domain.d/$app.conf
	
	systemctl reload nginx.service
}

config_synapse() {
	cp ../conf/homeserver.yaml /etc/matrix-synapse/homeserver.yaml
	cp ../conf/log.yaml /etc/matrix-synapse/log.yaml
	
	ynh_replace_string __DOMAIN__ $domain /etc/matrix-synapse/homeserver.yaml
	ynh_replace_string __SYNAPSE_DB_USER__ $synapse_db_user /etc/matrix-synapse/homeserver.yaml
	ynh_replace_string __SYNAPSE_DB_PWD__ $synapse_db_pwd /etc/matrix-synapse/homeserver.yaml
	ynh_replace_string __PORT__ $synapse_port /etc/matrix-synapse/homeserver.yaml
	ynh_replace_string __TLS_PORT__ $synapse_tls_port /etc/matrix-synapse/homeserver.yaml
	ynh_replace_string __TURNSERVER_TLS_PORT__ $turnserver_tls_port /etc/matrix-synapse/homeserver.yaml
	ynh_replace_string __TURNPWD__ $turnserver_pwd /etc/matrix-synapse/homeserver.yaml

	if [ "$is_public" = "0" ]
	then
		ynh_replace_string __ALLOWED_ACCESS__ False /etc/matrix-synapse/homeserver.yaml
	else
		ynh_replace_string __ALLOWED_ACCESS__ True /etc/matrix-synapse/homeserver.yaml
	fi
}

config_coturn() {
	cp ../conf/default_coturn /etc/default/coturn
	cp ../conf/turnserver.conf /etc/turnserver.conf
	
	ynh_replace_string __TURNPWD__ $turnserver_pwd /etc/turnserver.conf
	ynh_replace_string __DOMAIN__ $domain /etc/turnserver.conf
	ynh_replace_string __TLS_PORT__ $turnserver_tls_port /etc/turnserver.conf
}

set_certificat_access() {
	set_access $synapse_user /etc/yunohost/certs/$domain/crt.pem
	set_access $synapse_user /etc/yunohost/certs/$domain/key.pem
	set_access $synapse_user /etc/yunohost/certs/$domain/dh.pem

	set_access turnserver /etc/yunohost/certs/$domain/crt.pem
	set_access turnserver /etc/yunohost/certs/$domain/key.pem
	set_access turnserver /etc/yunohost/certs/$domain/dh.pem
}

set_access() { # example : set_access USER FILE
    user="$1"
    file_to_set="$2"
    while [[ 0 ]]
    do
        path_to_set=""
        oldIFS="$IFS"
        IFS="/"
        for dirname in $file_to_set
        do
            if [[ -n "$dirname" ]]
            then
                test -f "$path_to_set"/"$dirname" && setfacl -m d:u:$user:r "$path_to_set"
                
                path_to_set="$path_to_set/$dirname"
                
                if $(sudo -u $user test ! -r "$path_to_set")
                then
                    test -d "$path_to_set" && setfacl -m user:$user:rx  "$path_to_set"
                    test -f "$path_to_set" && setfacl -m user:$user:r  "$path_to_set"
                fi
            fi
        done
        IFS="$oldIFS"
        
        if $(test -L "$file_to_set")
        then
            if [[ -n "$(readlink "$file_to_set" | grep -e "^/")" ]]
            then
                file_to_set=$(readlink "$file_to_set") # If it is an absolute path
            else
                file_to_set=$(realpath -s -m "$(echo "$file_to_set" | cut -d'/' -f-$(echo "$file_to_set" | grep -o '/' | wc -l))/$(readlink "$file_to_set")") # If it is an relative path (we get with realpath the absolute path)
            fi
        else
            break
        fi
    done
}
