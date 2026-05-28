#!/usr/bin/env bash

# Detect the primary egress interface (IPv4) by asking the kernel
# how it would reach the Internet
get_default_iface() {
  ip -o -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}'
}

freepbxip="172.18.0.20"
rtp_port_range="10000-20000"
DEFAULT_IFACE="$(get_default_iface)"

if [[ -z "$DEFAULT_IFACE" ]]; then
  echo "ERROR: Could not detect default egress interface." >&2
  exit 1
fi

# Parse optional --rtp RANGE argument without affecting other flags
# Supports only "--rtp 10000-20000"
requested_rtp=""
prev=""
for arg in "$@"; do
  if [[ "$prev" == "--rtp" ]]; then
    requested_rtp="$arg"
    prev=""
    continue
  fi
  case "$arg" in
    --rtp)
      prev="--rtp"
      ;;
  esac
done

if [[ -n "$prev" ]]; then
  echo "ERROR: --rtp requires a value like 10000-20000" >&2
  exit 1
fi

if [[ -n "$requested_rtp" ]]; then
  if [[ "$requested_rtp" =~ ^[0-9]+-[0-9]+$ ]]; then
    start_port="${requested_rtp%%-*}"
    end_port="${requested_rtp##*-}"
    if (( end_port > start_port )); then
      rtp_port_range="$requested_rtp"
    else
      echo "ERROR: Invalid --rtp value '$requested_rtp'. The right number must be greater than the left (e.g., 10000-20000)." >&2
      exit 1
    fi
  else
    echo "ERROR: Invalid --rtp value '$requested_rtp'. Use two integers separated by '-' (e.g., 10000-20000)." >&2
    exit 1
  fi
fi

# INSTALL FREEPBX
if [[  "$*" == *"--install-freepbx"*  ]]; then
  sudo docker compose exec -it -w /usr/local/src/freepbx freepbx php install -n --dbuser=asterisk --dbpass="$(cat secrets/freepbxuser_password.txt)" --dbhost=ontaxivoipmysql0.mysql.database.azure.com

# Add Custom Modules
elif [[  "$*" == *"--add-modules"*  ]]; then
  sudo docker compose exec freepbx cp /usr/local/src/extensions_custom.conf /etc/asterisk/extensions_custom.conf
  sudo docker compose exec freepbx cp /usr/local/src/queues_post_custom.conf /etc/asterisk/queues_post_custom.conf
  sudo docker compose exec freepbx cp /usr/local/src/survey.php /var/lib/asterisk/agi-bin/survey.php
  sudo docker compose exec freepbx sed -i 's/;queue_log => mysql,general/queue_log => odbc,asteriskcdrdb,queuelog/' /etc/asterisk/extconfig.conf
  sudo docker compose exec freepbx fwconsole reload

# Update Queues
elif [[  "$*" == *"--update-queues"*  ]]; then
  sudo docker compose cp ./source/asterisk/survey_config/queues_post_custom.conf freepbx:/etc/asterisk/queues_post_custom.conf
  sudo docker compose exec freepbx fwconsole reload

# Update Manager Config
elif [[  "$*" == *"--update-manager"*  ]]; then
  source .env
  sudo docker compose cp ./source/asterisk/stats/manager_custom.conf freepbx:/etc/asterisk/manager_custom.conf
  sudo docker compose exec freepbx sed -i "/\[monast\]/,/^\[/{s/secret = .*/secret = ${MONAST_PASSW}/}" /etc/asterisk/manager_custom.conf
  sudo docker compose exec freepbx fwconsole reload

# Update Start Heplify
elif [[  "$*" == *"--start-heplify"*  ]]; then
  docker compose exec -d freepbx /usr/local/bin/heplify -i any -hs 172.16.0.4:9060 -hn voip0 -hi 1 -l error -dd -zf -t af_packet -m SIPRTCP

# CLEAN
elif [[  "$*" == *"--clean-all"*  ]]; then
  read -r -p "Are you sure you want to clean up everything? Data will be lost. (yes/no)? " confirmation
  if [[ "$confirmation" != "yes" ]]; then
    echo "Cleanup aborted."
    exit 0
  fi
  # DB is external (Azure) - no local db container to remove
  sudo docker container stop freepbx-docker-freepbx-1 && sudo docker container rm freepbx-docker-freepbx-1
  sudo docker container stop fail2ban && sudo docker container rm fail2ban
  sudo docker volume rm freepbx-docker_var_asterisk_data
  sudo docker volume rm freepbx-docker_etc_data
  sudo docker volume rm freepbx-docker_logs_asterisk_data
  sudo docker volume rm freepbx-docker_www_data
  sudo docker volume rm freepbx-docker_fail2ban_data
  # mysql_data volume removed (DB is external)
  sudo docker network rm freepbx-docker_defaultnet


# UNSUPPORTED HOST CASE
elif [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "MINGW" ]]; then
    echo "$OSTYPE currently not supported, please manually configure your host firewall to allow incoming and outgoing UDP traffic on the RTP port range: $rtp_port_range"

# Configure Iptables for RTP ports on Linux
else
    if [[  "$OSTYPE" == "linux-gnu"*  ]]; then
        echo "Configuring iptables rules for RTP ports"

        # Allow incoming UDP traffic to container on the RTP port range on the DOCKER-USER chain 
        # to ensure media packets are accepted before other rules are applied.
        if ! sudo iptables -C DOCKER-USER -p udp -d "$freepbxip" --dport "${rtp_port_range/-/:}" -j ACCEPT 2>/dev/null; then
            sudo iptables -I DOCKER-USER -p udp -d "$freepbxip" --dport "${rtp_port_range/-/:}" -j ACCEPT \
            && echo "Rule for incoming RTP traffic added!"
        else
            echo "Rule for incoming RTP traffic already in place."
        fi

        # Destination NAT for RTP: forward inbound UDP traffic arriving on the default egress interface
        # and matching the RTP port range to the FreePBX host.
        if ! sudo iptables -t nat -C PREROUTING -i "$DEFAULT_IFACE" -p udp --dport "${rtp_port_range/-/:}" \
            -j DNAT --to-destination "$freepbxip:${rtp_port_range/:/-}" 2>/dev/null; then
            sudo iptables -t nat -A PREROUTING -i "$DEFAULT_IFACE" -p udp --dport "${rtp_port_range/-/:}" \
            -j DNAT --to-destination "$freepbxip:${rtp_port_range/:/-}" && echo "Rule for Destination NAT RTP added!"
        else
            echo "Rule for Destination NAT RTP already in place."
        fi

        # Build and start the Compose services
        sudo docker compose up -d
    fi

fi