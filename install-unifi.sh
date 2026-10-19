#!/usr/bin/env bash
set -e

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root."
  exit 1
fi

echo "=== 1. Looking up available network bridges ==="
bridges=($(ip -o link show | grep -oE 'vmbr[0-9]+' | sort -u))

if [ ${#bridges[@]} -eq 0 ]; then
  echo "Error: No Proxmox network bridges (vmbr...) found on this host!"
  exit 1
fi

echo "Choose the network bridge you want to use for the LXC container:"
select ACTIVE_BRIDGE in "${bridges[@]}"; do
  if [ -n "$ACTIVE_BRIDGE" ]; then
    echo "=> Selected network bridge: $ACTIVE_BRIDGE"
    break
  else
    echo "Invalid choice, please try again."
  fi
done

echo "=== 2. Finding the next available Container ID ==="
CTID=$(pvesh get /cluster/nextid)
HOSTNAME="unifi-toolkit"
STORAGE="local-lvm"       # Change this if your Proxmox storage has a different name
TEMPLATE_STORAGE="local"  # Storage location for templates
ROOT_PASS="Welcome123"     # Root password for the container

echo "=== 3. Checking and preparing Ubuntu 24.04 LXC Template ==="
pveam update
if ! pveam list $TEMPLATE_STORAGE | grep -q "ubuntu-24.04"; then
    echo "Downloading Ubuntu 24.04 template..."
    TEMPLATE_NAME=$(pveam available -section system | grep ubuntu-24.04 | head -n 1 | awk '{print $2}')
    pveam download $TEMPLATE_STORAGE $TEMPLATE_NAME
fi

TEMPLATE_FILE=$(pveam list $TEMPLATE_STORAGE | grep ubuntu-24.04 | head -n 1 | awk '{print $1}')
TEMPLATE_FILE=$(basename "$TEMPLATE_FILE")

echo "=== 4. Creating LXC Container (ID: $CTID) on bridge '$ACTIVE_BRIDGE' ==="
pct create $CTID $TEMPLATE_STORAGE:vztmpl/$TEMPLATE_FILE \
    --ostype ubuntu \
    --hostname $HOSTNAME \
    --cores 2 \
    --memory 1024 \
    --swap 512 \
    --rootfs $STORAGE:8 \
    --net0 name=eth0,bridge=$ACTIVE_BRIDGE,ip=dhcp,firewall=0 \
    --nameserver 8.8.8.8 \
    --unprivileged 1 \
    --onboot 1 \
    --start 1

echo "=== Waiting for the container to start and obtain an IP (10 sec)... ==="
sleep 10

echo "=== 5. Setting root password ==="
echo "root:$ROOT_PASS" | pct exec $CTID -- chpasswd

echo "=== 6. Installing Python, Git, and UniFi Toolkit inside the container ==="
pct exec $CTID -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y python3.12 python3.12-venv python3-pip git build-essential curl

mkdir -p /opt/unifi-toolkit
git clone https://github.com/Crosstalk-Solutions/unifi-toolkit.git /opt/unifi-toolkit
cd /opt/unifi-toolkit

python3.12 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create systemd service for automatic startup
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

# Try to retrieve the container's IP address
LXC_IP=$(pct exec $CTID -- hostname -I 2>/dev/null | awk '{print $1}')

echo ""
echo "===================================================="
echo " Installation successfully completed! "
echo " Container ID  : $CTID"
echo " Used bridge   : $ACTIVE_BRIDGE"
echo " Login via     : pct enter $CTID (or via SSH)"
echo " Root Password : $ROOT_PASS"
echo " Web interface : http://${LXC_IP:-<container-ip>}:8000"
echo "===================================================="
