Synapse for YunoHost
====================

Yunohost chattroom with matrix : [https://riot.im/app/#/room/#yunohost:matrix.org](https://riot.im/app/#/room/#yunohost:matrix.org)

[Yunohost project](https://yunohost.org/#/)

[![Integration level](https://dash.yunohost.org/integration/synapse.svg)](https://ci-apps.yunohost.org/jenkins/job/synapse%20%28Community%29/lastBuild/consoleFull) 

Setup
-----

### Install for ARM arch (or slow arch)

For all slow or arm architecture it's recommended to build the dh file before the install to have quicker install.
You could built it by this cmd : `mkdir -p /etc/matrix-synapse && openssl dhparam -out /etc/matrix-synapse/dh.pem 2048 > /dev/null`
After that you can install it without problem.

The package use a prebuild python virtualenvironnement. The binary are taken from this repos : https://github.com/Josue-T/synapse_python_build
The script to build the binary is also available.

### Package update package

`sudo yunohost app upgrade synapse -u https://github.com/YunoHost-Apps/synapse_ynh`

### Web client

If you want a web client you can also install riot with this package : https://github.com/YunoHost-Apps/riot_ynh . But 

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

Install
-------

From command line:

`sudo yunohost app install -l synapse https://github.com/YunoHost-Apps/synapse_ynh`

Upgrade
-------

From command line:

`sudo yunohost app upgrade synapse -u https://github.com/YunoHost-Apps/synapse_ynh`

Issue
-----

Any issue is welcome here : https://github.com/YunoHost-Apps/synapse_ynh/issues

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

To do
-----

- Doc (issue about domain)
- Test arm
- Riot doc
- Test production

### Todo for official App

- Improve documentation
