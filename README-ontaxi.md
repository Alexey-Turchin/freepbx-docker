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

| Port              | Description |
| ----------------- | ----------- |
| `80/tcp`          | HTTP        |
| `443/tcp`         | HTTPS       |
| `5060/udp`        | PJSIP       |

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

## Usage
1. Create required passwords:
```bash
# for MySQL root user
printf "yourstrongmysqlfreepbxuserpassword" > freepbxuser_password.txt

# Set proper file permissions
chmod 600 freepbxuser_password.txt
```

## Build the image from scratch:
```bash
docker compose build
```

## Settings for Azure Database
Go to the Azure Portal and change:  
`require_secure_transport` = OFF  
`sql_generate_invisible_primary_key` = OFF  

## Run the Compose project and Install FreePBX:
```bash
# Run Containers
sudo bash run.sh

# Optional, If you want to override the default RTP port range (10000-20000):
sudo bash run.sh --rtp 10000-20000
# NOTE
# If you run the script with the default RTP range 10000-20000 and later rerun it with a different range, the iptables rules from the previous range remain in place and you have to delete those rules manually before or after applying the new range.

# Install Freepbx
sudo bash run.sh --install-freepbx

# Optional, clean up containers, network and volumes
sudo bash run.sh --clean-all
```

## TLS support using Let's Encrypt DNS challenge
```bash
# Make sure to have both 80 and 443 TCP ports allowed by the firewall and a valid DNS record A
sudo docker compose exec -it freepbx certbot --apache -d your.domain.com --email your-email@email.com --agree-tos --redirect -n
```

Login to the web server's admin URL and start configuring the system!