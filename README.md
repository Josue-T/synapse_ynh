Synapse for YunoHost
====================

![](https://matrix.org/blog/wp-content/uploads/2015/01/logo1.png)

[![Integration level](https://dash.yunohost.org/integration/synapse.svg)](https://ci-apps.yunohost.org/jenkins/job/synapse%20%28Community%29/lastBuild/consoleFull)

[![Install Synapse with YunoHost](https://install-app.yunohost.org/install-with-yunohost.png)](https://install-app.yunohost.org/?app=synapse)

[Yunohost project](https://yunohost.org/#/)

Overview
--------

Instant messaging server matrix network.

Yunohost chattroom with matrix : [https://riot.im/app/#/room/#yunohost:matrix.org](https://riot.im/app/#/room/#yunohost:matrix.org)

Shipped version: 0.26.0

Configuration
-------------

### Install for ARM arch (or slow arch)

For all slow or arm architecture it's recommended to build the dh file before the install to have quicker install.
You could built it by this cmd : `mkdir -p /etc/matrix-synapse && openssl dhparam -out /etc/matrix-synapse/dh.pem 2048 > /dev/null`
After that you can install it without problem.

The package use a prebuild python virtualenvironnement. The binary are taken from this repos : https://github.com/Josue-T/synapse_python_build
The script to build the binary is also available.

### Web client

If you want a web client you can also install riot with this package : https://github.com/YunoHost-Apps/riot_ynh .

### Access by federation

To be accessible by the federation you need to put this following  line in the dns configuration :

```
_matrix._tcp.<yourdomain.com> <ttl> IN SRV 10 0 <port> <synapse.server.name>
```
for example
```
_matrix._tcp.example.com. 3600    IN      SRV     10 0 8448 synapse.example.com.
```
### Important Security Note

We do not recommend running Riot from the same domain name as your Matrix
homeserver (synapse).  The reason is the risk of XSS (cross-site-scripting)
vulnerabilities that could occur if someone caused Riot to load and render
malicious user generated content from a Matrix API which then had trusted
access to Riot (or other apps) due to sharing the same domain.

We have put some coarse mitigations into place to try to protect against this
situation, but it's still not good practice to do it in the first place.  See
https://github.com/vector-im/riot-web/issues/1977 for more details.

Documentation
-------------

- Official documentation: https://github.com/matrix-org/synapse
- YunoHost documentation: to be created ; feel free to help!

YunoHost specific features
--------------------------

### Multi-users support

Supported with LDAP.

### Supported architectures

- Tested on x86_64
- Tested on ARM (with specific build)

Limitations
-----------

Synapse take a lot of ressurce. So in slow architecture (like small ARM board), this app could take a lot of CPU and RAM.

This app don't contains any real good web interface. So it's recommended to use Riot client to connect to this app. This app is available [here](https://github.com/YunoHost-Apps/riot_ynh)

Links
-----

- Report a bug: https://github.com/YunoHost-Apps/synapse_ynh/issues
- Matrix website: https://matrix.org/
- YunoHost website: https://yunohost.org/

Developers infos
----------------

Please do your pull request to the testing branch.

To try the testing branch, please proceed like that:

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/synapse_ynh/tree/testing --verbose
or
sudo yunohost app upgrade synapse -u https://github.com/YunoHost-Apps/synapse_ynh/tree/testing --verbose
```

Administation
-------------

**All documentation of this section is not warranted. A bad use of command could broke the app and all the data. So use theses command at your own risk.**

Before any manipulation it's recommended to do a backup by this following command :

`sudo yunohost backup create --verbose --ignore-system --apps synapse`

### Set user as admin

Actually there are no function in the client interface to set a user as admin. So it's possible to enable it manually in the database.

This following command will enable the admin access to the specified user :
```
su --command="psql matrix_synapse" postgres <<< "UPDATE users SET admin = 1 WHERE name = '@user_to_be_admin:domain.tld'"
```

### Disable backup in upgrade

To solve the issue [#30](https://github.com/YunoHost-Apps/synapse_ynh/issues/30) you can disable the upgrade in the upgrade by setting to true the key `disable_backup_before_upgrade` in the app setting. You can set it by this command :

`yunohost app setting synapse disable_backup_before_upgrade -v 1`

Multi instance support
----------------------

To give a possiblity to have multiple domain you can use synapse in multiple instance. In this case all instance will run on differents port so it's really important to use put a SRV record in your domain. You can get the port that your need to put in your SRV record by this following command :
```
yunohost app setting synapse__<instancenumber> synapse_tls_port
```

Before to install a second instance of the app it's really recommend to update all instance already installed.


Migration from old package
--------------------------

The old synapse package had some problem, the package has been reviewed in the summer 2017. The old package was made with the debian package with the synapse apt repos. The database used sqlite. To improve the performance and to have a better compatibility the new package use python virtual environment and postgresql as database. The Upgrade was made to make the migration from the old package to the new package. The part of this script is available here : https://github.com/YunoHost-Apps/synapse_ynh/blob/master/scripts/upgrade#L40-L119 .

This script try to upgrade the app without any problem but it could happen that something fail and in this case it NOT guaranteed that the restored successfully. So it's REALLY recommended to make manually a backup before this big upgrade.

To check if you use the old synapse package type this command :
`sudo yunohost app setting synapse synapse_version`
- If the command return nothing you are using the old package.
- If the command return something like 0.25.1 you are using the new package.

To do a backup before the upgrade use this command : `sudo yunohost backup create --verbose --ignore-system --apps synapse`

If anything fail while you are doing the upgrade please make an issue here : https://github.com/YunoHost-Apps/synapse_ynh/issues

License
-------

Synapse is published under the Apache License : https://github.com/matrix-org/synapse/blob/master/LICENSE
