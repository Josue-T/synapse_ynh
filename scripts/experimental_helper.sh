# Read the value of a key in a ynh manifest file
#
# usage: ynh_read_manifest manifest key
# | arg: manifest - Path of the manifest to read
# | arg: key - Name of the key to find
ynh_read_manifest () {
	manifest="$1"
	key="$2"
	python3 -c "import sys, json;print(json.load(open('$manifest'))['$key'])"
}

# Read the upstream version from the manifest 
# this include the number before ~ynh
#
# usage: ynh_app_upstream_version
ynh_app_upstream_version () {
    manifest_path="../manifest.json"
    if [ ! -e "$manifest_path" ]; then
        manifest_path="../settings/manifest.json"	# Into the restore script, the manifest is not at the same place
    fi
    version_key=$(ynh_read_manifest "$manifest_path" "version")
    echo "${version_key/~ynh*/}"
}

# Read package version from the manifest 
# this include the number after ~ynh
#
# usage: ynh_app_package_version
ynh_app_package_version () {
    manifest_path="../manifest.json"
    if [ ! -e "$manifest_path" ]; then
        manifest_path="../settings/manifest.json"	# Into the restore script, the manifest is not at the same place
    fi
    version_key=$(ynh_read_manifest "$manifest_path" "version")
    echo "${version_key/*~ynh/}"
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
# usage: ynh_check_starting "Line to match" [Log file] [Timeout] [Service name]
#
# | arg: Line to match - The line to find in the log to attest the service have finished to boot.
# | arg: Log file - The log file to watch
# | arg: Service name
# /var/log/$app/$app.log will be used if no other log is defined.
# | arg: Timeout - The maximum time to wait before ending the watching. Defaut 300 seconds.
ynh_check_starting () {
	local line_to_match="$1"
	local service_name="${4:-$app}"
	local app_log="${2:-/var/log/$service_name/$service_name.log}"
	local timeout=${3:-300}

	ynh_clean_check_starting () {
		# Stop the execution of tail.
		kill -s 15 $pid_tail 2>&1
		ynh_secure_remove "$templog" 2>&1
	}

	echo "Starting of $service_name" >&2
	systemctl restart $service_name
	local templog="$(mktemp)"
	# Following the starting of the app in its log
	tail -F -n1 "$app_log" > "$templog" &
	# Get the PID of the tail command
	local pid_tail=$!

	local i=0
	for i in `seq 1 $timeout`
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

# Create a dedicated systemd config
#
# usage: ynh_add_systemd_config [Service name] [Source file]
# | arg: Service name
# | arg: Systemd source file (for example appname.service)
#
# This will use a template in ../conf/systemd.service
# and will replace the following keywords with 
# global variables that should be defined before calling
# this helper :
#
#   __APP__       by  $app
#   __FINALPATH__ by  $final_path
#
# usage: ynh_add_systemd_config
ynh_add_systemd_config () {
	local service_name="${1:-$app}"

	finalsystemdconf="/etc/systemd/system/$service_name.service"
	ynh_backup_if_checksum_is_different "$finalsystemdconf"
	sudo cp ../conf/${2:-systemd.service} "$finalsystemdconf"

	# To avoid a break by set -u, use a void substitution ${var:-}. If the variable is not set, it's simply set with an empty variable.
	# Substitute in a nginx config file only if the variable is not empty
	if test -n "${final_path:-}"; then
		ynh_replace_string "__FINALPATH__" "$final_path" "$finalsystemdconf"
	fi
	if test -n "${app:-}"; then
		ynh_replace_string "__APP__" "$app" "$finalsystemdconf"
	fi
	ynh_store_file_checksum "$finalsystemdconf"

	sudo chown root: "$finalsystemdconf"
	sudo systemctl enable $service_name
	sudo systemctl daemon-reload
}

# Remove the dedicated systemd config
#
# usage: ynh_remove_systemd_config [Service name]
# | arg: Service name
#
# usage: ynh_remove_systemd_config
ynh_remove_systemd_config () {
	local service_name="${1:-$app}"

	local finalsystemdconf="/etc/systemd/system/$service_name.service"
	if [ -e "$finalsystemdconf" ]; then
		sudo systemctl stop $service_name
		sudo systemctl disable $service_name
		ynh_secure_remove "$finalsystemdconf"
		sudo systemctl daemon-reload
	fi
}
