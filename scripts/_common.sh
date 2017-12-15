#!/bin/bash

# Retrieve arguments
app=$YNH_APP_INSTANCE_NAME
synapse_user="matrix-synapse"
synapse_db_name="matrix_synapse"
synapse_db_user="matrix_synapse"

get_app_version_from_json() {
   manifest_path="../manifest.json"
    if [ ! -e "$manifest_path" ]; then
    	manifest_path="../settings/manifest.json"	# Into the restore script, the manifest is not at the same place
    fi
    echo $(grep '\"version\": ' "$manifest_path" | cut -d '"' -f 4)	# Retrieve the version number in the manifest file.
}
APP_VERSION=$(get_app_version_from_json)

install_dependances() {
	ynh_install_app_dependencies coturn build-essential python2.7-dev libffi-dev python-pip python-setuptools sqlite3 libssl-dev python-virtualenv libxml2-dev libxslt1-dev python-lxml libjpeg-dev libpq-dev postgresql acl
	pip install --upgrade pip
	pip install --upgrade virtualenv
}

setup_dir() {
    # Create empty dir for synapse
    mkdir -p /var/lib/matrix-synapse
    mkdir -p /var/log/matrix-synapse
    mkdir -p /var/log/turnserver
    mkdir -p /etc/matrix-synapse/conf.d
    mkdir -p $final_path
}

set_permission() {
    # Set permission
    chown $synapse_user:root -R $final_path
    chown $synapse_user:root -R /var/lib/matrix-synapse
    chown $synapse_user:root -R /var/log/matrix-synapse
    chown turnserver:root -R /var/log/turnserver
    chown $synapse_user:root -R /etc/matrix-synapse
}

install_source() {
	if [ -n "$(uname -m | grep arm)" ]
	then
		ynh_replace_string __APP_VERSION__ $APP_VERSION "$YNH_CWD/../conf/armv7.src"
		ynh_setup_source $final_path/ "armv7"
	else
		# Install virtualenv if it don't exist
		test -e $final_path/bin || virtualenv -p python2.7 $final_path

		# Install synapse in virtualenv
		PS1=""
		cp ../conf/virtualenv_activate $final_path/bin/activate
		source $final_path/bin/activate
		pip install --upgrade pip
		pip install --upgrade setuptools
		pip install --upgrade cffi ndg-httpsclient psycopg2 lxml
		pip install --upgrade https://github.com/matrix-org/synapse/archive/v$APP_VERSION.tar.gz
		deactivate
	fi
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


####### Solve issue https://dev.yunohost.org/issues/1006

# Build and install a package from an equivs control file
#
# example: generate an empty control file with `equivs-control`, adjust its
#          content and use helper to build and install the package:
#              ynh_package_install_from_equivs /path/to/controlfile
#
# usage: ynh_package_install_from_equivs controlfile
# | arg: controlfile - path of the equivs control file
ynh_package_install_from_equivs () {
    controlfile=$1

    # Check if the equivs package is installed. Or install it.
    ynh_package_is_installed 'equivs' \
        || ynh_package_install equivs

    # retrieve package information
    pkgname=$(grep '^Package: ' $controlfile | cut -d' ' -f 2)	# Retrieve the name of the debian package
    pkgversion=$(grep '^Version: ' $controlfile | cut -d' ' -f 2)	# And its version number
    [[ -z "$pkgname" || -z "$pkgversion" ]] \
        && echo "Invalid control file" && exit 1	# Check if this 2 variables aren't empty.

    # Update packages cache
    ynh_package_update

    # Build and install the package
    TMPDIR=$(mktemp -d)
    # Note that the cd executes into a sub shell
    # Create a fake deb package with equivs-build and the given control file
    # Install the fake package without its dependencies with dpkg
    # Install missing dependencies with ynh_package_install
    (cp "$controlfile" "${TMPDIR}/control" && cd "$TMPDIR" \
     && equivs-build ./control 1>/dev/null \
     && sudo dpkg --force-depends \
          -i "./${pkgname}_${pkgversion}_all.deb" 2>&1 \
     && ynh_package_install -f) || ynh_die "Unable to install dependencies"
    [[ -n "$TMPDIR" ]] && rm -rf $TMPDIR	# Remove the temp dir.

    # check if the package is actually installed
    ynh_package_is_installed "$pkgname"
}

# Implement PR : https://github.com/YunoHost/yunohost/pull/392

# Use logrotate to manage the logfile
#
# usage: ynh_use_logrotate [logfile] [--non-append]
# | arg: logfile - absolute path of logfile
# | option: --non-append - Replace the config file instead of appending this new config.
#
# If no argument provided, a standard directory will be use. /var/log/${app}
# You can provide a path with the directory only or with the logfile.
# /parentdir/logdir
# /parentdir/logdir/logfile.log
#
# It's possible to use this helper several times, each config will be added to the same logrotate config file.
# Unless you use the option --non-append
ynh_use_logrotate () {
	local customtee="tee -a"
	if [ $# -gt 0 ] && [ "$1" == "--non-append" ]; then
		customtee="tee"
		# Destroy this argument for the next command.
		shift
	elif [ $# -gt 1 ] && [ "$2" == "--non-append" ]; then
		customtee="tee"
	fi
	if [ $# -gt 0 ]; then
		if [ "$(echo ${1##*.})" == "log" ]; then	# Keep only the extension to check if it's a logfile
			logfile=$1	# In this case, focus logrotate on the logfile
		else
			logfile=$1/*.log	# Else, uses the directory and all logfile into it.
		fi
	else
		logfile="/var/log/${app}/*.log" # Without argument, use a defaut directory in /var/log
	fi
	cat > ./${app}-logrotate << EOF	# Build a config file for logrotate
$logfile {
		# Rotate if the logfile exceeds 100Mo
	size 100M
		# Keep 12 old log maximum
	rotate 12
		# Compress the logs with gzip
	compress
		# Compress the log at the next cycle. So keep always 2 non compressed logs
	delaycompress
		# Copy and truncate the log to allow to continue write on it. Instead of move the log.
	copytruncate
		# Do not do an error if the log is missing
	missingok
		# Not rotate if the log is empty
	notifempty
		# Keep old logs in the same dir
	noolddir
}
EOF
	sudo mkdir -p $(dirname "$logfile")	# Create the log directory, if not exist
	cat ${app}-logrotate | sudo $customtee /etc/logrotate.d/$app > /dev/null	# Append this config to the existing config file, or replace the whole config file (depending on $customtee)
}
