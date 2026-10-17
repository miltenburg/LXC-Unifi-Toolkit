#!/usr/bin/env bash
# Copyright (c) 2021-2026 tteck / Community Scripts
# Adapted for UniFi Toolkit

# Standaard tteck variabelen voor de container
APP="UniFi-Toolkit"
var_tags="${var_tags:-unifi;toolkit}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_arm64="${var_arm64:-no}"
var_unprivileged="${var_unprivileged:-1}"

# Laad het tteck core framework voor de container-bouw
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

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

msg_info "Configuring UniFi Toolkit inside the container..."
lxc-attach -n "$CTID" -- bash -c "
  apt update && apt install -y git python3 python3-pip python3-venv build-essential curl
  mkdir -p /opt/unifi-toolkit
  git clone https://github.com/Crosstalk-Solutions/unifi-toolkit.git /opt/unifi-toolkit
  cd /opt/unifi-toolkit
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt

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
echo -e "${INFO}${YW}Note: Don't forget to run './setup.sh' inside the container via 'pct enter ${CTID}' if you need to configure your environment variables/keys.${CL}"
