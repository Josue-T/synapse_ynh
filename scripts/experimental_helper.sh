# Read the value of a key in a ynh manifest file
#
# usage: ynh_read_manifest manifest key
# | arg: manifest - Path of the manifest to read
# | arg: key - Name of the key to find
ynh_read_manifest () {
	manifest="$1"
	key="$2"
	python3 -c "import sys, json;print(json.load(open('$manifest', encoding='utf-8'))['$key'])"
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

# Send an email to inform the administrator
#
# usage: ynh_send_readme_to_admin app_message [recipients]
# | arg: app_message - The message to send to the administrator.
# | arg: recipients - The recipients of this email. Use spaces to separate multiples recipients. - default: root
#	example: "root admin@domain"
#	If you give the name of a YunoHost user, ynh_send_readme_to_admin will find its email adress for you
#	example: "root admin@domain user1 user2"
ynh_send_readme_to_admin() {
	local app_message="${1:-...No specific information...}"
	local recipients="${2:-root}"

	# Retrieve the email of users
	find_mails () {
		local list_mails="$1"
		local mail
		local recipients=" "
		# Read each mail in argument
		for mail in $list_mails
		do
			# Keep root or a real email address as it is
			if [ "$mail" = "root" ] || echo "$mail" | grep --quiet "@"
			then
				recipients="$recipients $mail"
			else
				# But replace an user name without a domain after by its email
				if mail=$(ynh_user_get_info "$mail" "mail" 2> /dev/null)
				then
					recipients="$recipients $mail"
				fi
			fi
		done
		echo "$recipients"
	}
	recipients=$(find_mails "$recipients")

	local mail_subject="☁️🆈🅽🅷☁️: \`$app\` was just installed!"

	local mail_message="This is an automated message from your beloved YunoHost server.

Specific information for the application $app.

$app_message

---
Automatic diagnosis data from YunoHost

$(yunohost tools diagnosis | grep -B 100 "services:" | sed '/services:/d')"

	# Define binary to use for mail command
	if [ -e /usr/bin/bsd-mailx ]
	then
		local mail_bin=/usr/bin/bsd-mailx
	else
		local mail_bin=/usr/bin/mail.mailutils
	fi

	# Send the email to the recipients
	echo "$mail_message" | $mail_bin -a "Content-Type: text/plain; charset=UTF-8" -s "$mail_subject" "$recipients"
}

# Create a dedicated fail2ban config (jail and filter conf files)
#
# usage: ynh_add_fail2ban_config "list of others variables to replace"
#
# | arg: list of others variables to replace separeted by a space
# |      for example : 'var_1 var_2 ...'
#
# This will use a template in ../conf/f2b_jail.conf and ../conf/f2b_filter.conf
#   __APP__      by  $app
#
#  You can dynamically replace others variables by example :
#   __VAR_1__    by $var_1
#   __VAR_2__    by $var_2
#
# Note about the "failregex" option:
#          regex to match the password failure messages in the logfile. The
#          host must be matched by a group named "host". The tag "<HOST>" can
#          be used for standard IP/hostname matching and is only an alias for
#          (?:::f{4,6}:)?(?P<host>[\w\-.^_]+)
#
#          You can find some more explainations about how to make a regex here :
#          https://www.fail2ban.org/wiki/index.php/MANUAL_0_8#Filters
#
# Note that the logfile need to exist before to call this helper !!
#
# Generally your template will look like that by example (for synapse):
#
# f2b_jail.conf:
#     [__APP__]
#     enabled = true
#     port = http,https
#     filter = __APP__
#     logpath = /var/log/__APP__/logfile.log
#     maxretry = 3
#
# f2b_filter.conf:
#     [INCLUDES]
#     before = common.conf
#     [Definition]
#
#     # Part of regex definition (just used to make more easy to make the global regex)
#     __synapse_start_line = .? \- synapse\..+ \-
#
#    # Regex definition.
#    failregex = ^%(__synapse_start_line)s INFO \- POST\-(\d+)\- <HOST> \- \d+ \- Received request\: POST /_matrix/client/r0/login\??<SKIPLINES>%(__synapse_start_line)s INFO \- POST\-\1\- Got login request with identifier: \{u'type': u'm.id.user', u'user'\: u'(.+?)'\}, medium\: None, address: None, user\: u'\5'<SKIPLINES>%(__synapse_start_line)s WARNING \- \- (Attempted to login as @\5\:.+ but they do not exist|Failed password login for user @\5\:.+)$
#
#     ignoreregex =
#
# To validate your regex you can test with this command:
# fail2ban-regex /var/log/YOUR_LOG_FILE_PATH /etc/fail2ban/filter.d/YOUR_APP.conf
ynh_add_fail2ban_config () {
  local others_var=${1:-}

  finalfail2banjailconf="/etc/fail2ban/jail.d/$app.conf"
  finalfail2banfilterconf="/etc/fail2ban/filter.d/$app.conf"
  ynh_backup_if_checksum_is_different "$finalfail2banjailconf"
  ynh_backup_if_checksum_is_different "$finalfail2banfilterconf"

  cp ../conf/f2b_jail.conf $finalfail2banjailconf
  cp ../conf/f2b_filter.conf $finalfail2banfilterconf

  if test -n "${app:-}"; then
    ynh_replace_string "__APP__" "$app" "$finalfail2banjailconf"
    ynh_replace_string "__APP__" "$app" "$finalfail2banfilterconf"
  fi

  # Replace all other variable given as arguments
  for var_to_replace in $others_var; do
    # ${var_to_replace^^} make the content of the variable on upper-cases
    # ${!var_to_replace} get the content of the variable named $var_to_replace
    ynh_replace_string --match_string="__${var_to_replace^^}__" --replace_string="${!var_to_replace}" --target_file="$finalfail2banjailconf"
    ynh_replace_string --match_string="__${var_to_replace^^}__" --replace_string="${!var_to_replace}" --target_file="$finalfail2banfilterconf"
  done

  ynh_store_file_checksum "$finalfail2banjailconf"
  ynh_store_file_checksum "$finalfail2banfilterconf"

  systemctl try-reload-or-restart fail2ban

  local fail2ban_error="$(journalctl -u fail2ban | tail -n50 | grep "WARNING.*$app.*")"
  if [[ -n "$fail2ban_error" ]]; then
    echo "[ERR] Fail2ban failed to load the jail for $app" >&2
    echo "WARNING${fail2ban_error#*WARNING}" >&2
  fi
}

# Remove the dedicated fail2ban config (jail and filter conf files)
#
# usage: ynh_remove_fail2ban_config
ynh_remove_fail2ban_config () {
  ynh_secure_remove "/etc/fail2ban/jail.d/$app.conf"
  ynh_secure_remove "/etc/fail2ban/filter.d/$app.conf"
  systemctl try-reload-or-restart fail2ban
}
