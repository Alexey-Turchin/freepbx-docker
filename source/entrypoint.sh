#!/usr/bin/env bash
set -e

ensure_freepbx_cli_links() {
  local cli_name target_path

  for cli_name in fwconsole amportal; do
    target_path="/var/lib/asterisk/bin/${cli_name}"
    if [[ -e "$target_path" ]]; then
      ln -sfn "$target_path" "/usr/sbin/${cli_name}"
    fi
  done
}

ensure_freepbx_cli_links

# Start cron
/usr/sbin/cron &

# Start Asterisk service
/usr/local/src/freepbx/start_asterisk start &

# Start heplify
/usr/local/bin/heplify -i any -hs 172.16.0.4:9060 -hn voip0 -hi 1 -l error -dd -zf -t af_packet -m SIPRTCP &

exec apache2ctl -D FOREGROUND
