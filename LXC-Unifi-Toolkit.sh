#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 tteck / Community Scripts
# Adapted for UniFi Toolkit on Ubuntu 24.04

APP="UniFi-Toolkit"
var_tags="${var_tags:-unifi;toolkit}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"
var_arm64="${var_arm64:-no}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -d /opt/unifi-toolkit ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating UniFi Toolkit"
    set +e
    lxc-attach -n "$CTID" -- bash -c "
      cd /opt/unifi-toolkit
      git pull
      source venv/bin/activate
      pip install --upgrade pip
      pip install -r requirements.txt
      systemctl restart unifi-toolkit
    "
    msg_ok "Updated UniFi Toolkit successfully!"
    exit
}

start
build_container
description

msg_info "Configuring UniFi Toolkit and installing dependencies inside the container..."
lxc-attach -n "$CTID" -- bash -c "
  # Pakketten bijwerken en installeren (inclusief Python 3.12, venv, pip en git)
  apt update && apt upgrade -y
  apt install -y python3.12 python3.12-venv python3-pip git build-essential curl

  # Installatiemap aanmaken
  mkdir -p /opt/unifi-toolkit

  # Repository clonen
  git clone https://github.com/Crosstalk-Solutions/unifi-toolkit.git /opt/unifi-toolkit

  # Naar de map gaan, venv aanmaken en requirements installeren
  cd /opt/unifi-toolkit
  python3.12 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt

  # Systemd service aanmaken voor achtergrond-uitvoering
  cat << 'EOF' > /etc/systemd/system/unifi-toolkit.service
[Unit]
Description=UniFi Toolkit Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/unifi-toolkit
ExecStart=/opt/unifi-toolkit/venv/bin/python /opt/unifi-toolkit/run.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable unifi-toolkit
  systemctl start unifi-toolkit
"

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:8000${CL}"
echo -e "${INFO}${YW}Tip: Om de setup-wizard te doorlopen (bijv. .env configureren), typ op de host:${CL}"
echo -e "${GATEWAY}${BGN}pct enter ${CTID} en ga naar /opt/unifi-toolkit en voer ./setup.sh uit${CL}"
