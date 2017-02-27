#!/bin/bash

md5sum_python_nacl="34c44f8f5100170bae3b4329ffb43087"
md5sum_python_ujson="5b65f8cb6bedef7971fdc557e09effbe"
python_nacl_version="1.0.1-2"
python_ujson_version="1.35-1"

init_script() {
    # Exit on command errors and treat unset variables as an error
    set -eu

    # Source YunoHost helpers
    source /usr/share/yunohost/helpers

    # Retrieve arguments
    app=$YNH_APP_INSTANCE_NAME
    CHECK_VAR "$app" "app name not set"
    GET_DEBIAN_VERSION
    
    if [ -n "$(uname -m | grep 64)" ]; then
            ARCHITECTURE="amd64"
    elif [ -n "$(uname -m | grep 86)" ]; then
            ARCHITECTURE="386"
    elif [ -n "$(uname -m | grep arm)" ]; then
            ARCHITECTURE="arm"
    else
            ynh_die "Unable to find arch"
    fi
}

install_arm_package_dep() {

    wget -q -O '/tmp/python-nacl.deb' "http://ftp.ch.debian.org/debian/pool/main/p/python-nacl/python-nacl_${python_nacl_version}_armhf.deb"
    wget -q -O '/tmp/python-ujson.deb' "http://ftp.ch.debian.org/debian/pool/main/u/ujson/python-ujson_${python_ujson_version}_armhf.deb"

    if ([[ ! -e '/tmp/python-nacl.deb' ]] || [[ $(md5sum '/tmp/python-nacl.deb' | cut -d' ' -f1) != $md5sum_python_nacl ]]) || \
        ([[ ! -e '/tmp/python-ujson.deb' ]] || [[ $(md5sum '/tmp/python-ujson.deb' | cut -d' ' -f1) != $md5sum_python_ujson ]])
    then
        ynh_die "Error : can't get debian dependance package"
    fi
    
    sudo dpkg -i /tmp/python-nacl.deb || true
    sudo dpkg -i /tmp/python-ujson.deb || true
}

GET_DEBIAN_VERSION() {
    debian_version=$(sudo lsb_release -sc)
    test -z $debian_version && ynh_die "Can't find debian version"
    test $debian_version == 'jessie' || ynh_die "This package is not available for your debian version"
}

enable_backport_repos() {
    if [[ -z "$(grep -e "^deb .*/.* $debian_version-backports main" /etc/apt/sources.list ; grep -e "^deb .*/.* $debian_version-backports main" /etc/apt/sources.list.d/*.list)" ]]
    then
        echo "deb $(grep -m 1 "^deb .* $debian_version .*main" /etc/apt/sources.list | cut -d ' ' -f2) $debian_version-backports main contrib non-free" | sudo tee -a "/etc/apt/sources.list"
    fi
    ynh_package_update
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
            sudo test -f "$path_to_set"/"$dirname" && sudo setfacl -m d:u:$user:r "$path_to_set"
            
            path_to_set="$path_to_set/$dirname"
            
            if $(sudo sudo -u $user test ! -r "$path_to_set")
            then
                sudo test -d "$path_to_set" && sudo setfacl -m user:$user:rx  "$path_to_set"
                sudo test -f "$path_to_set" && sudo setfacl -m user:$user:r  "$path_to_set"
            fi
        fi
    done
    IFS="$oldIFS"
    
    if $(sudo test -L "$file_to_set")
    then
        if [[ -n "$(sudo readlink "$file_to_set" | grep -e "^/")" ]]
        then
            file_to_set=$(sudo readlink "$file_to_set") # If it is an absolute path
        else
            file_to_set=$(sudo realpath -s -m "$(echo "$file_to_set" | cut -d'/' -f-$(echo "$file_to_set" | grep -o '/' | wc -l))/$(sudo readlink "$file_to_set")") # If it is an relative path (we get with realpath the absolute path)
        fi
    else
        break
    fi
done
}

CHECK_VAR () {	# Vérifie que la variable n'est pas vide.
# $1 = Variable à vérifier
# $2 = Texte à afficher en cas d'erreur
	test -n "$1" || (echo "$2" >&2 && false)
}

# Ignore the yunohost-cli log to prevent errors with conditionals commands
# usage: NO_LOG COMMAND
# Simply duplicate the log, execute the yunohost command and replace the log without the result of this command
# It's a very badly hack...
# Petite copie perso à mon usage ;)
NO_LOG() {
  ynh_cli_log=/var/log/yunohost/yunohost-cli.log
  sudo cp -a ${ynh_cli_log} ${ynh_cli_log}-move
  eval $@
  exit_code=$?
  sudo mv ${ynh_cli_log}-move ${ynh_cli_log}
  return $?
}

CHECK_PATH () {	# Vérifie la présence du / en début de path. Et son absence à la fin.
	if [ "${path:0:1}" != "/" ]; then    # Si le premier caractère n'est pas un /
		path="/$path"    # Ajoute un / en début de path
	fi
	if [ "${path:${#path}-1}" == "/" ] && [ ${#path} -gt 1 ]; then    # Si le dernier caractère est un / et que ce n'est pas le seul caractère.
		path="${path:0:${#path}-1}"	# Supprime le dernier caractère
	fi
}

CHECK_DOMAINPATH () {	# Vérifie la disponibilité du path et du domaine.
	sudo yunohost app checkurl $domain$path -a $app
}

CHECK_FINALPATH () {	# Vérifie que le dossier de destination n'est pas déjà utilisé.
	final_path=/var/www/$app
	if [ -e "$final_path" ]
	then
		echo "This path already contains a folder" >&2
		false
	fi
}

FIND_PORT () {	# Cherche un port libre.
# $1 = Numéro de port pour débuter la recherche.
	port=$1
	while ! sudo yunohost app checkport $port ; do
		port=$((port+1))
	done
	CHECK_VAR "$port" "port empty"
}


### REMOVE SCRIPT

REMOVE_NGINX_CONF () {	# Suppression de la configuration nginx
	if [ -e "/etc/nginx/conf.d/$domain.d/$app.conf" ]; then	# Delete nginx config
		echo "Delete nginx config"
		sudo rm "/etc/nginx/conf.d/$domain.d/$app.conf"
		sudo service nginx reload
	fi
}

REMOVE_LOGROTATE_CONF () {	# Suppression de la configuration de logrotate
	if [ -e "/etc/logrotate.d/$app" ]; then
		echo "Delete logrotate config"
		sudo rm "/etc/logrotate.d/$app"
	fi
}
