#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "Starting system hardening validation..."

# Function to display result
check_result() {
    if [[ $1 -eq 0 ]]; then
        echo "[PASS] $2"
    else
        echo "[FAIL] $2"
    fi
}

# 1. Validate system updates
echo "Checking system updates..."
if command -v apt >/dev/null 2>&1; then
    apt update -y >/dev/null 2>&1
    apt list --upgradable | grep -q "upgradable"
    check_result $? "System is up to date"
elif command -v yum >/dev/null 2>&1; then
    yum check-update -q >/dev/null 2>&1
    check_result $? "System is up to date"
else
    echo "[WARN] Package manager not found."
fi

# 2. Validate iptables configuration
echo "Checking iptables configuration..."
iptables -L -n | grep -q "ACCEPT"
check_result $? "iptables rules are active"

# 3. Validate Firewalld
echo "Checking Firewalld status..."
systemctl is-active firewalld >/dev/null 2>&1
check_result $? "Firewalld is running"

# 4. Validate SSH hardening
echo "Validating SSH configuration..."
grep -q "^Port 2222" /etc/ssh/sshd_config && \
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config && \
grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config && \
grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config
check_result $? "SSH configuration is hardened"

# 5. Validate Lynis installation and audit
echo "Checking Lynis installation..."
if command -v lynis >/dev/null 2>&1; then
    lynis audit system --quick >/dev/null 2>&1
    check_result $? "Lynis is installed and functional"
else
    echo "[FAIL] Lynis is not installed."
fi

# 6. Validate rkhunter installation and rootkit scan
echo "Checking rkhunter installation and rootkit scans..."
if command -v rkhunter >/dev/null 2>&1; then
    rkhunter --versioncheck >/dev/null 2>&1
    check_result $? "rkhunter is installed and updated"
    rkhunter --check --sk >/dev/null 2>&1
    check_result $? "No rootkits detected by rkhunter"
else
    echo "[FAIL] rkhunter is not installed."
fi

# 7. Validate ClamAV
echo "Checking ClamAV status..."
systemctl is-active clamav-daemon >/dev/null 2>&1
check_result $? "ClamAV is running"

# 8. Validate file permissions
echo "Checking file permissions..."
stat -c "%a" /root | grep -q "700" && \
stat -c "%a" /etc/ssh | grep -q "700" && \
stat -c "%a" /etc/ssh/sshd_config | grep -q "600" && \
find /var/log -type d -perm 700 | grep -q "/var/log"
check_result $? "File permissions are correctly set"

# 9. Validate auditd
echo "Checking auditd status..."
systemctl is-active auditd >/dev/null 2>&1
check_result $? "auditd is running"

# 10. Validate password policy
echo "Checking password policy..."
grep -q "minlen = 12" /etc/security/pwquality.conf && \
grep -q "minclass = 4" /etc/security/pwquality.conf
check_result $? "Password policy is configured"

# 11. Validate automatic updates
echo "Checking automatic updates..."
if command -v apt >/dev/null 2>&1; then
    grep -q 'APT::Periodic::Unattended-Upgrade "1";' /etc/apt/apt.conf.d/20auto-upgrades
    check_result $? "Automatic updates are enabled"
elif command -v yum >/dev/null 2>&1; then
    systemctl is-enabled yum-cron >/dev/null 2>&1
    check_result $? "Automatic updates are enabled"
else
    echo "[WARN] Could not verify automatic updates."
fi

# 12. Validate unnecessary services are disabled
echo "Validating unnecessary services..."
for service in cups avahi-daemon bluetooth; do
    systemctl is-enabled $service >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo "[FAIL] $service is still enabled."
    else
        echo "[PASS] $service is disabled."
    fi
done

# Final message
echo "Validation complete. Review the results above."
