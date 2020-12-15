dependances="coturn build-essential python3-dev libffi-dev python3-pip python3-setuptools sqlite3 libssl-dev python3-venv libxml2-dev libxslt1-dev python3-lxml zlib1g-dev libjpeg-dev libpq-dev postgresql acl"
python_version="$(python3 -V | cut -d' ' -f2 | cut -d. -f1-2)"

install_sources() {
    # Install/upgrade synapse in virtualenv

    # Clean venv is it was on python2.7 or python3 with old version in case major upgrade of debian
    if [ ! -e $final_path/bin/python3 ] || [ ! -e $final_path/lib/python$python_version ]; then
        ynh_secure_remove --file=$final_path
    fi

    mkdir -p $final_path

    if [ -n "$(uname -m | grep arm)" ]
    then
        # Clean old file, sometimes it could make some big issues if we don't do this!!
        ynh_secure_remove --file=$final_path/bin
        ynh_secure_remove --file=$final_path/lib
        ynh_secure_remove --file=$final_path/include
        ynh_secure_remove --file=$final_path/share

        ynh_setup_source --dest_dir=$final_path/ --source_id="armv7_$(lsb_release --codename --short)"

        # Fix multi-instance support
        for f in $(ls $final_path/bin); do
            if ! [[ $f =~ "__" ]]; then
                ynh_replace_special_string --match_string='#!/opt/yunohost/matrix-synapse' --replace_string='#!'$final_path --target_file=$final_path/bin/$f
            fi
        done
    else
        # Install virtualenv if it don't exist
        test -e $final_path/bin/python3 || python3 -m venv $final_path

        # Install synapse in virtualenv

        # We set all necessary environement variable to create a python virtualenvironnement.
        set +u;
        source $final_path/bin/activate
        set -u;
        pip3 install --upgrade setuptools wheel
        pip3 install --upgrade cffi ndg-httpsclient psycopg2 lxml jinja2
        pip3 install --upgrade 'Twisted>=20.3.0' 'cryptography>=3.3' matrix-synapse==$upstream_version matrix-synapse-ldap3

        # This function was defined when we called "source $final_path/bin/activate". With this function we undo what "$final_path/bin/activate" does
        set +u;
        deactivate
        set -u;
    fi
}
