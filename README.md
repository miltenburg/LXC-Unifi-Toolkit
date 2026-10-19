local deployment script:

nano install-unifi.sh
chmod +x install-unifi.sh
./install-unifi.sh


REMARK: the other lxc script is working correctly !!!!

Run the command below in the Proxmox VE Shell or your Incus host shell to install Unifi Toolkit.

bash -c "$(curl -fsSL https://raw.githubusercontent.com/patmilt/LXC-Unifi-Toolkit/main/LXC-Unifi-Toolkit.sh)"
