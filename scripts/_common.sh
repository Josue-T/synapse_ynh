#!/bin/bash

# Retrieve arguments
app=$YNH_APP_INSTANCE_NAME
synapse_user="matrix-$app"
synapse_db_name="matrix_$app"
synapse_db_user="matrix_$app"

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
		pip install --upgrade https://github.com/matrix-org/synapse/archive/v$APP_VERSION.tar.gz
		
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

# Start or restart a service and follow its booting
#
# usage: ynh_check_starting "Line to match" [service name] [Log file] [Timeout]
#
# | arg: Line to match - The line to find in the log to attest the service have finished to boot.
# | arg: Log file - The log file to watch
# /var/log/$app/$app.log will be used if no other log is defined.
# | arg: Timeout - The maximum time to wait before ending the watching. Defaut 300 seconds.
ynh_check_starting () {
	local line_to_match="$1"
	local service_name="${2:-$app}"
	local app_log="${3:-/var/log/$app/$app.log}"
	local timeout=${4:-300}

	ynh_clean_check_starting () {
		# Stop the execution of tail.
		kill -s 15 $pid_tail 2>&1
		ynh_secure_remove "$templog" 2>&1
	}

	echo "Starting of $service_name" >&2
	systemctl restart $service_name
	
	local i=0
	local templog="$(mktemp)"
	
	# Wait if the log file don't exist
	if [[ ! -e $app_log ]]
	then
		for i in $(seq 1 $timeout)
		do
			if [[ -e $app_log ]]
			then
				cat $app_log > "$templog"
				break
			fi
			echo -n "." >&2
			sleep 1
		done
	fi
	
	# Following the starting of the app in its log
	tail -f -n1 "$app_log" >> "$templog" &
	# Get the PID of the tail command
	local pid_tail=$!

	for i in $(seq $i $timeout)
	do
		# Read the log until the sentence is found, that means the app finished to start. Or run until the timeout
		if grep --quiet "$line_to_match" "$templog"
		then
			echo "The service $service_name has correctly started." >&2
			break
		fi
		echo -n "." >&2
		sleep 1
	done
	if [ $i -eq $timeout ]
	then
		echo "The service $service_name didn't fully started before the timeout." >&2
	fi

	echo ""
	ynh_clean_check_starting
}