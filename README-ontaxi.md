## Introduction

This is MVP [Docker Compose](https://docs.docker.com/compose/) application for having [FreePBX](https://www.freepbx.org) - A Voice over IP manager for [Asterisk](https://www.asterisk.org), running in containers.

Upon starting this multi-container application, it will give you a turnkey PBX system for SIP calling.

* FreePBX 17.0.21
* PHP 8.2.29
* Asterisk 21.10.2
* Azure MySQL Flexible Server
* Fail2ban pre-configured with restrictive enforcement rules
* Logrotate configured also for Asterisk and Freepbx
* Supports data persistence
* Base image Debian [debian:bookworm-slim](https://hub.docker.com/_/debian/)
* Apache 2.4.65
* NodeJS v18.20.4
* DAHDI channel not supported

### Ports
The following ports are exposed via Docker.

| Port              | Description  |
| ----------------- | ------------ |
| `80/tcp`          | HTTP         |
| `443/tcp`         | HTTPS        |
| `5038/tcp`        | AMI          |
| `5060/udp`        | PJSIP        |
| `8088/tcp`        | Asterisk REST|

RTP ports e.g. `10000-20000/udp` require a particular configuration in order to be
properly exposed.\
There's a [known issue](https://github.com/moby/moby/issues/11185) about Docker and its way to expose a large range of ports, since each port exposed loads another process into memory and you may be experiencing a low memory condition.\
As a trade-off, those ports are going to be exposed via Docker host `iptables` manually.\
So [run.sh](run.sh) will take care of iptables configuration, besides building and running the image.

### Host requirements
- `ip`, `iptables` and `awk` commands
- iptables rules inside the Docker chains will bypass any firewall rule on the system
- Iptables rules are temporary, unless you make them persistent in this way (Debian-like):
```bash
sudo apt-get update
sudo apt-get install -y iptables-persistent
sudo systemctl enable netfilter-persistent
sudo systemctl restart netfilter-persistent
sudo systemctl status netfilter-persistent
```
  
## Settings for Azure Database
Go to the Azure Portal and change:  
`require_secure_transport` = OFF  
`sql_generate_invisible_primary_key` = OFF  
### Create databases for FreePBX
Read `init.sql`
Execute query on the db server:
```sql
-- Create asterisk database
CREATE DATABASE IF NOT EXISTS asterisk;
-- Create asteriskcdr database
CREATE DATABASE IF NOT EXISTS asteriskcdrdb;
```
### Create database for Survey custom module
Read `source/db/init-survey.sql`
Execute query on the db server:
```sql
-- Create DB
CREATE DATABASE IF NOT EXISTS asterisksurvey;

-- Create table
CREATE TABLE IF NOT EXISTS `survey` (
  `id` int NOT NULL AUTO_INCREMENT,
  `num` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `operator` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `queue` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `valuation` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```
  
## Usage
Create required passwords:
```bash
# for MySQL user
printf "mysql_password" > secrets/freepbxuser_password.txt

# Set proper file permissions
chmod 600 freepbxuser_password.txt
```
Change Database host in `source/odbc/odbc.ini`  
Example
```bash
[MySQL-asteriskcdrdb]
Description = MySQL connection to 'asteriskcdrdb' database
Driver = MySQL
Server = voipmysql0.mysql.database.azure.com
Database = asteriskcdrdb
Port = 3306
Option = 3
```

## Build the image from scratch:
```bash
docker compose build
```

## Run the Compose project and Install FreePBX:
### Run Containers
```bash
bash run.sh
```
OPTIONAL, If you want to override the default RTP port range (10000-20000):
```bash
bash run.sh --rtp 10000-20000
# NOTE
# If you run the script with the default RTP range 10000-20000 and later rerun it with a different range, the iptables rules from the previous range remain in place and you have to delete those rules manually before or after applying the new range.
```
### Install Freepbx (First time only)
```bash
bash run.sh --install-freepbx
```
### Restore FreePBX Backup (First time only)
Upload the backup archive to the GUI and restore
### Install OnTaxi Custom Modules (First time only)
Add custom modules after restore the FreePBX backup
```bash
bash run.sh --add-modules
```

### Working with Queues
Edit queue file `source/asterisk/survey_configs/queues_post_custom.conf`
```bash
; Example for adding queue sip-users
[98000](+)
member=Local/9809@customer-survey-ivr/n,0,9809 Katerina Rakovets,hint:9809@ext-local

[99000](+)
member=Local/9907@customer-survey-ivr/n,0,9907 Svetlana Yakovleva,hint:9907@ext-local

[12002](+)
member=Local/9907@customer-survey-ivr/n,0,9907 Svetlana Yakovleva,hint:9907@ext-local
```
Push changes to the repository and pull on the server
Add changes to the VOIP server
```bash
bash run.sh --update-queues
```
### Working with AMI users (for Monast, Stats, etc)
Edit AMI users file `source/asterisk/stats/manager_custom.conf`  
Example:
```bash
[monast]
secret = 
permit=0.0.0.0/0.0.0.0
read = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate,message
write = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate,message
writetimeout = 10
```
Create `.env` file with password variable  
```bash
MONAST_PASSW=secret_password
```
Apply configuration to Asterisk
```bash
bash run.sh --update-manager
```
  
### Clean up containers, network and volumes (DANGER)
> [!CAUTION]
> Removes all things about Freepbx
```bash
bash run.sh --clean-all
```
  
## TLS support using Let's Encrypt DNS challenge
```bash
# Make sure to have both 80 and 443 TCP ports allowed by the firewall and a valid DNS record A
docker compose exec -it freepbx certbot --apache -d your.domain.com --email your-email@email.com --agree-tos --redirect -n
```

Login to the web server's admin URL and start configuring the system!