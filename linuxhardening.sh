#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

LOGFILE="/var/log/server_hardening.log"
echo "$(date): Starting server hardening process..." | tee -a $LOGFILE

confirm() {
    read -p "$1 (yes/no): " choice
    case "$choice" in
        yes|y|Y) return 0 ;;
        no|n|N) echo "Skipping this step." | tee -a $LOGFILE; return 1 ;;
        *) echo "Invalid input. Please enter yes or no."; confirm "$1" ;;
    esac
}

# Update and Upgrade System
if confirm "Do you want to update and upgrade the system?"; then
    echo "Updating and upgrading system packages..." | tee -a $LOGFILE
    apt update && apt upgrade -y || yum update -y | tee -a $LOGFILE
else
    echo "Skipping system update." | tee -a $LOGFILE
fi

# Install Required Packages
echo "Installing essential packages..." | tee -a $LOGFILE
apt install -y ufw fail2ban iptables-persistent auditd clamav unattended-upgrades || yum install -y firewalld fail2ban audit clamav epel-release -y | tee -a $LOGFILE

# Configure UFW
if confirm "Do you want to configure UFW?"; then
    echo "Configuring UFW..." | tee -a $LOGFILE
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw default deny incoming
    ufw default allow outgoing
    ufw enable | tee -a $LOGFILE
else
    echo "Skipping UFW configuration." | tee -a $LOGFILE
fi

# Configure Firewalld (if UFW is unavailable)
if ! command -v ufw &> /dev/null && confirm "Do you want to configure Firewalld?"; then
    echo "Configuring Firewalld..." | tee -a $LOGFILE
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --set-default-zone=public
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload | tee -a $LOGFILE
fi

# Configure Fail2Ban
if confirm "Do you want to configure Fail2Ban?"; then
    echo "Configuring Fail2Ban..." | tee -a $LOGFILE
    cat <<EOL > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 3600
findtime  = 600
maxretry = 5

[sshd]
enabled = true
port    = 22
filter  = sshd
logpath = /var/log/auth.log
EOL
    systemctl enable fail2ban
    systemctl restart fail2ban | tee -a $LOGFILE
else
    echo "Skipping Fail2Ban configuration." | tee -a $LOGFILE
fi

# Set Sysctl Parameters
if confirm "Do you want to configure kernel parameters?"; then
    echo "Configuring kernel parameters..." | tee -a $LOGFILE
    cat <<EOL > /etc/sysctl.d/hardening.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOL
    sysctl --system | tee -a $LOGFILE
else
    echo "Skipping kernel parameter configuration." | tee -a $LOGFILE
fi

# Configure SSH
if confirm "Do you want to harden SSH?"; then
    echo "Hardening SSH configuration..." | tee -a $LOGFILE
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd | tee -a $LOGFILE
else
    echo "Skipping SSH hardening." | tee -a $LOGFILE
fi

# Run Antivirus Scan
if confirm "Do you want to install and run ClamAV?"; then
    echo "Installing and configuring ClamAV..." | tee -a $LOGFILE
    freshclam
    clamscan -r --bell -i / | tee -a $LOGFILE
else
    echo "Skipping ClamAV installation." | tee -a $LOGFILE
fi

# Install and Configure Auditd
if confirm "Do you want to install and configure Auditd?"; then
    echo "Configuring Auditd..." | tee -a $LOGFILE
    systemctl enable auditd
    systemctl start auditd
    auditctl -e 1 | tee -a $LOGFILE
else
    echo "Skipping Auditd configuration." | tee -a $LOGFILE
fi

# Enable Automatic Updates
if confirm "Do you want to enable automatic updates?"; then
    echo "Enabling automatic updates..." | tee -a $LOGFILE
    dpkg-reconfigure -plow unattended-upgrades | tee -a $LOGFILE
else
    echo "Skipping automatic updates." | tee -a $LOGFILE
fi

# Final Message
echo "$(date): Server hardening process complete. Review $LOGFILE for details." | tee -a $LOGFILE
read -p "Reboot the system now? (yes/no): " REBOOT
if [[ $REBOOT =~ ^[Yy](es)?$ ]]; then
    reboot
fi
