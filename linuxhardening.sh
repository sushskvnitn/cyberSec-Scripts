#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

confirm() {
    read -p "$1 (yes/no): " choice
    case "$choice" in
        yes|y|Y) return 0 ;;
        no|n|N) echo "Skipping this step."; return 1 ;;
        *) echo "Invalid input. Please enter yes or no."; confirm "$1" ;;
    esac
}

echo "Starting the system hardening process..."

# Update and upgrade the system
if confirm "Do you want to update and upgrade the system?"; then
    apt update && apt upgrade -y || yum update -y
else
    echo "Skipping system update."
fi

# Configure iptables for kernel-level firewall
if confirm "Do you want to configure iptables for kernel-level firewall?"; then
    iptables -F
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -j DROP
    iptables-save > /etc/iptables/rules.v4
else
    echo "Skipping iptables configuration."
fi

# Configure Firewalld
if confirm "Do you want to configure Firewalld?"; then
    apt install firewalld -y || yum install firewalld -y
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
else
    echo "Skipping Firewalld configuration."
fi

# SSH Hardening
if confirm "Do you want to harden SSH configuration?"; then
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    echo "HostKeyAlgorithms +ssh-ed25519" >> /etc/ssh/sshd_config
    echo "KexAlgorithms +curve25519-sha256" >> /etc/ssh/sshd_config
    systemctl restart sshd
else
    echo "Skipping SSH hardening."
fi

# Install Lynis for auditing
if confirm "Do you want to install Lynis for auditing?"; then
    apt install lynis -y || yum install lynis -y
    echo "Running Lynis security audit scans..."
    lynis audit system > /root/lynis_system_audit.log
    lynis audit security-controls > /root/lynis_security_controls_audit.log
    lynis audit software > /root/lynis_software_audit.log
else
    echo "Skipping Lynis installation and scans."
fi

# Install and run rkhunter for rootkit detection
if confirm "Do you want to install and run rkhunter for rootkit detection?"; then
    apt install rkhunter -y || yum install rkhunter -y
    rkhunter --update
    rkhunter --check --skip-keypress
    rkhunter --remove
else
    echo "Skipping rkhunter installation and checks."
fi

#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

confirm() {
    read -p "$1 (yes/no): " choice
    case "$choice" in
        yes|y|Y) return 0 ;;
        no|n|N) echo "Skipping this step."; return 1 ;;
        *) echo "Invalid input. Please enter yes or no."; confirm "$1" ;;
    esac
}

echo "Starting the enhanced system hardening process..."

# Disable unnecessary services
if confirm "Do you want to disable unnecessary services (CUPS, Avahi, Bluetooth)?"; then
    echo "Disabling unnecessary services..."
    systemctl disable cups 2>/dev/null
    systemctl disable avahi-daemon 2>/dev/null
    systemctl disable bluetooth 2>/dev/null
    echo "Unnecessary services disabled."
else
    echo "Skipping disabling unnecessary services."
fi

# Install and configure antivirus (ClamAV)
if confirm "Do you want to install and configure ClamAV antivirus?"; then
    echo "Installing ClamAV..."
    apt install clamav clamav-daemon -y || yum install clamav clamav-update -y
    freshclam
    systemctl enable clamav-daemon
    systemctl start clamav-daemon
    echo "ClamAV installed and configured."
else
    echo "Skipping ClamAV installation."
fi

# Set strong file permissions
if confirm "Do you want to set strong file permissions?"; then
    echo "Setting file permissions..."
    chmod 700 /root
    chmod 700 /etc/ssh
    chmod 600 /etc/ssh/sshd_config
    chmod -R go-rwx /var/log
    echo "File permissions set."
else
    echo "Skipping setting file permissions."
fi

# Install and configure auditd
if confirm "Do you want to install and configure auditd for monitoring?"; then
    echo "Installing and configuring auditd..."
    apt install auditd -y || yum install audit -y
    systemctl enable auditd
    systemctl start auditd
    auditctl -e 1
    echo "Auditd installed and monitoring enabled."
else
    echo "Skipping auditd installation."
fi

# Enable automatic updates
if confirm "Do you want to enable automatic updates?"; then
    echo "Enabling automatic updates..."
    apt install unattended-upgrades -y
    dpkg-reconfigure -plow unattended-upgrades
    echo "Automatic updates enabled."
else
    echo "Skipping automatic updates configuration."
fi

# Check for world-writable files
if confirm "Do you want to check and fix world-writable files?"; then
    echo "Checking for world-writable files..."
    find / -xdev -type f -perm -0002 -exec chmod o-w {} \;
    echo "World-writable files fixed."
else
    echo "Skipping check for world-writable files."
fi

# Remove unnecessary packages
if confirm "Do you want to remove unnecessary packages?"; then
    echo "Removing unnecessary packages..."
    apt autoremove -y || yum autoremove -y
    echo "Unnecessary packages removed."
else
    echo "Skipping removal of unnecessary packages."
fi

# Configure password policy
if confirm "Do you want to configure password policy?"; then
    echo "Configuring password policy..."
    cat <<EOF >> /etc/security/pwquality.conf
minlen = 12
minclass = 4
EOF
    echo "Password policy configured."
else
    echo "Skipping password policy configuration."
fi

# Final message
echo "System hardening complete. Review the audit reports and validation checks."
echo "Reboot the system to ensure all changes take effect."
