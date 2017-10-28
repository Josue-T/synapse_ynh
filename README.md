Synapse for YunoHost
====================

Yunohost chattroom with matrix : [https://riot.im/app/#/room/#yunohost:matrix.org](https://riot.im/app/#/room/#yunohost:matrix.org)

[Yunohost project](https://yunohost.org/#/)

Setup
-----

### Install for ARM arch (or slow arch)

If you don't have a dh.pem file in `/etc/yunohost/certs/YOUR DOMAIN/dh.pem` you should built it befor to install the app because it could take a long time.
You could built it by this cmd : `sudo openssl dhparam -out /etc/yunohost/certs/YOUR DOMAIN/dh.pem 2048 > /dev/null`
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

- Improve the upgrade from old version (all feedback is welcome)
- Improve documentation
