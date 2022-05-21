# Synapse for YunoHost

![](https://matrix.org/blog/wp-content/uploads/2015/01/logo1.png)

[![Integration level](https://dash.yunohost.org/integration/synapse.svg)](https://dash.yunohost.org/appci/app/synapse) ![](https://ci-apps.yunohost.org/ci/badges/synapse.status.svg) ![](https://ci-apps.yunohost.org/ci/badges/synapse.maintain.svg)  
[![Install Synapse with YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=synapse)

> *This package allows you to install Synapse quickly and simply on a YunoHost server.  
If you don't have YunoHost, please see [here](https://yunohost.org/#/install) to know how to install and enjoy it.*

## Overview

Instant messaging server matrix network.

Yunohost chatroom with matrix : [https://riot.im/app/#/room/#yunohost:matrix.org](https://riot.im/app/#/room/#yunohost:matrix.org)

**Shipped version:** 1.59.0

## Configuration

### Install for ARM arch (or slow arch)

For all slow or arm architecture it's recommended to build the dh file before the install to have a quicker install.
You could build it by this cmd : `openssl dhparam -out /etc/ssl/private/dh2048.pem 2048 > /dev/null`
After that you can install it without problem.

The package uses a prebuilt python virtual environnement. The binary are taken from this repository: https://github.com/Josue-T/synapse_python_build
The script to build the binary is also available.

### Web client

If you want a web client you can also install Element with this package: https://github.com/YunoHost-Apps/element_ynh .

### Access by federation

If your server name is identical to the domain on which synapse is installed, and the default port 8448 is used, your server is normally already accessible by the federation.

If not, you can add the following line in the dns configuration but you normally don't need it as a .well-known file is edited during the install to declare your server name and port to the federation.

```
_matrix._tcp.<server_name.tld> <ttl> IN SRV 10 0 <port> <domain-or-subdomain-of-synapse.tld>
```
for example
```
_matrix._tcp.example.com. 3600    IN      SRV     10 0 SYNAPSE_PORT synapse.example.com.
```
You need to replace SYNAPSE_PORT by the real port. This port can be obtained by the command: `yunohost app setting SYNAPSE_INSTANCE_NAME synapse_tls_port`

For more details, see : https://github.com/matrix-org/synapse/blob/master/docs/federate.md

If it is not automatically done, you need to open this in your ISP box.

You also need a valid TLS certificate for the domain used by synapse. To do that you can refer to the documentation here : https://yunohost.org/#/certificate_en

### Turnserver

For Voip and video conferencing a turnserver is also installed (and configured). The turnserver listens on two UDP and TCP ports. You can get them with these commands:
```
yunohost app setting synapse turnserver_tls_port
yunohost app setting synapse turnserver_alt_tls_port

```
The turnserver will also choose a port dynamically when a new call starts. The range is between 49153 - 49193.

For some security reason the ports range (49153 - 49193) isn't automatically open by default. If you want to use the synapse server for voip or conferencing you will need to open this port range manually. To do this just run this command:

```
yunohost firewall allow Both 49153:49193
```

You might also need to open these ports (if it is not automatically done) on your ISP box.

To prevent the situation when the server is behind a NAT, the public IP is written in the turnserver config. By this the turnserver can send its real public IP to the client. For more information see [the coturn example config file](https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf#L102-L120).So if your IP changes, you could run the script `/opt/yunohost/__SYNAPSE_INSTANCE_NAME__/Coturn_config_rotate.sh` to update your config.

If you have a dynamic IP address, you also might need to update this config automatically. To do that just edit a file named `/etc/cron.d/coturn_config_rotate` and add the following content (just adapt the __SYNAPSE_INSTANCE_NAME__ which could be `synapse` or maybe `synapse__2`).

```
*/15 * * * * root bash /opt/yunohost/__SYNAPSE_INSTANCE_NAME__/Coturn_config_rotate.sh;
```

#### OpenVPN

In case of you have an OpenVPN server you might want than `coturn-synapse` restart when the VPN restart. To do this create a file named `/usr/local/bin/openvpn_up_script.sh` with this content:
```
#!/bin/bash

(
    sleep 5
    sudo systemctl restart coturn-synapse.service
) &
exit 0
```

Add this line in you sudo config file `/etc/sudoers`
```
openvpn    ALL=(ALL) NOPASSWD: /bin/systemctl restart coturn-synapse.service
```

And add this line in your OpenVPN config file
```
ipchange /usr/local/bin/openvpn_up_script.sh
```

### Important Security Note

We do not recommend running Element from the same domain name as your Matrix
homeserver (synapse).  The reason is the risk of XSS (cross-site-scripting)
vulnerabilities that could occur if someone caused Element to load and render
malicious user generated content from a Matrix API which then had trusted
access to Element (or other apps) due to sharing the same domain.

We have put some coarse mitigations into place to try to protect against this
situation, but it's still not a good practice to do it in the first place. See
https://github.com/vector-im/element-web/issues/1977 for more details.

## Documentation

- Official documentation: https://github.com/matrix-org/synapse
- YunoHost documentation: to be created; feel free to help!

## YunoHost specific features

### Multi-users support

Supported with LDAP.

### Supported architectures


* x86-64 - [![Build Status](https://ci-apps.yunohost.org/ci/logs/synapse%20%28Apps%29.svg)](https://ci-apps.yunohost.org/ci/apps/synapse/)
* ARMv8-A - [![Build Status](https://ci-apps-arm.yunohost.org/ci/logs/synapse%20%28Apps%29.svg)](https://ci-apps-arm.yunohost.org/ci/apps/synapse/)

## Limitations

Synapse uses a lot of ressource. So on slow architecture (like small ARM board), this app could take a lot of CPU and RAM.

This app doesn't provide any real good web interface. So it's recommended to use Element client to connect to this app. This app is available [here](https://github.com/YunoHost-Apps/element_ynh)

## Additional information

## Administation

**All documentation of this section is not warranted. A bad use of command could break the app and all the data. So use these commands at your own risk.**

Before any manipulation it's recommended to do a backup by this following command :

`sudo yunohost backup create --apps synapse`

### Set user as admin

Actually there are no functions in the client interface to set a user as admin. So it's possible to enable it manually in the database.

The following command will grant admin privilege to the specified user:
```
su --command="psql matrix_synapse" postgres <<< "UPDATE users SET admin = 1 WHERE name = '@user_to_be_admin:domain.tld'"
```

### Upgrade

By default a backup is made before the upgrade. To avoid this you have theses following possibilites:
- Pass the `NO_BACKUP_UPGRADE` env variable with `1` at each upgrade. By example `NO_BACKUP_UPGRADE=1 yunohost app upgrade synapse`.
- Set the settings `disable_backup_before_upgrade` to `1`. You can set this with this command:

`yunohost app setting synapse disable_backup_before_upgrade -v 1`

After this settings will be applied for **all** next upgrade.

From command line:

`yunohost app upgrade synapse`

### Backup

This app use now the core-only feature of the backup. To keep the integrity of the data and to have a better guarantee of the restoration is recommended to proceed like this:

- Stop synapse service with theses following command:

`systemctl stop synapse.service`

- Launch the backup of synapse with this following command:

`yunohost backup create --app synapse`

- Do a backup of your data with your specific strategy (could be with rsync, borg backup or just cp). The data is generally stored in `/home/yunohost.app/matrix-synapse`.
- Restart the synapse service with theses command:

`systemctl start synapse.service`

### Remove

Due of the backup core only feature the data directory in `/home/yunohost.app/matrix-synapse` **is not removed**. It need to be removed manually to purge app user data.

### Multi instance support

To give a possibility to have multiple domains you can use multiple instances of synapse. In this case all instances will run on different ports so it's really important to put a SRV record in your domain. You can get the port that you need to put in your SRV record with this following command:
```
yunohost app setting synapse__<instancenumber> synapse_tls_port
```

Before installing a second instance of the app it's really recommended to update all existing instances.

### Migration from old package

The old synapse package had some problems, the package has been reviewed in the summer 2017. The old package was made with the debian package with the synapse apt repos. The database used sqlite. To improve the performance and to have a better compatibility the new package uses python virtual environment and postgresql as database. The Upgrade was made to make the migration from the old package to the new package. The part of this script is available here : https://github.com/YunoHost-Apps/synapse_ynh/blob/master/scripts/upgrade#L40-L119 .

This script tries to upgrade the app without any problem but it could happen that something fails and in this case the restoration is NOT guaranteed to be successful. So it's REALLY recommended to make MANUAL a backup before this big upgrade.

To check if you use the old synapse package type this command:
`sudo yunohost app setting synapse synapse_version`
- If the command returns nothing you are using the old package.
- If the command returns something like 0.25.1 you are using the new package.

To do a backup before the upgrade use this command : `sudo yunohost backup create --verbose --ignore-system --apps synapse`

If anything fails while you are doing the upgrade please create an issue here: https://github.com/YunoHost-Apps/synapse_ynh/issues

### License

Synapse is published under the Apache License: https://github.com/matrix-org/synapse/blob/master/LICENSE

## Links

- Report a bug: https://github.com/YunoHost-Apps/synapse_ynh/issues
- Matrix website: https://matrix.org/
- Synapse repository: https://github.com/matrix-org/synapse
- YunoHost website: https://yunohost.org/

---

Developers infos
----------------

Please do your pull request to the [testing branch](https://github.com/YunoHost-Apps/synapse_ynh/tree/testing).

To try the testing branch, please proceed like that:

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/synapse_ynh/tree/testing --debug
or
sudo yunohost app upgrade synapse -u https://github.com/YunoHost-Apps/synapse_ynh/tree/testing --debug
```
