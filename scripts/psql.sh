# # Execute a command as root user
#
# usage: ynh_psql_execute_as_root sql [db]
# | arg: sql - the SQL command to execute
# | arg: db - the database to connect to
ynh_psql_execute_as_root () {
	sudo su -c "psql" - postgres <<< ${1}
}

# Create a user
#
# usage: ynh_psql_create_user user pwd [host]
# | arg: user - the user name to create
# | arg: pwd - the password to identify user by
ynh_psql_create_user() {
	ynh_psql_execute_as_root \
	"CREATE USER ${1} WITH PASSWORD '${2}';"
}

# Create a database and grant optionnaly privilegies to a user
#
# usage: ynh_psql_create_db db [user [pwd]]
# | arg: db - the database name to create
# | arg: user - the user to grant privilegies
# | arg: pwd - the password to identify user by
ynh_psql_create_db() {
    db=$1
    # grant all privilegies to user
    if [[ $# -gt 1 ]]; then
        ynh_psql_create_user ${2} "${3}"
        sudo su -c "createdb -O ${2} $db" -  postgres
    else
        sudo su -c "createdb $db" -  postgres
    fi

}

# Drop a database
#
# usage: ynh_psql_drop_db db
# | arg: db - the database name to drop
ynh_psql_drop_db() {
    sudo su -c "dropdb ${1}" -  postgres
}

# Drop a user
#
# usage: ynh_psql_drop_user user
# | arg: user - the user name to drop
ynh_psql_drop_user() {
    sudo su -c "dropuser ${1}" - postgres
}

ynh_psql_test_if_first_run() {
	if [ -f /etc/yunohost/psql ];
	then
		echo "PostgreSQL is already installed, no need to create master password"
	else
		local pgsql=$(ynh_string_random)
		echo "$pgsql" >> /etc/yunohost/psql
		systemctl start postgresql
		sudo -u postgres psql -c "ALTER user postgres WITH PASSWORD '${pgsql}'"
		# we can t use peer since YunoHost create users with nologin
		sed -i '/local\s*all\s*all\s*peer/i \
			local all all password' /etc/postgresql/9.4/main/pg_hba.conf
		systemctl enable postgresql
		systemctl reload postgresql
	fi
}