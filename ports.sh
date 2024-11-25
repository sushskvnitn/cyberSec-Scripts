#!/bin/bash

# Function to list open ports and associated services
function check_open_ports {
    echo "Checking open ports on the system..."
    echo "======================================"
    ss -tuln | awk 'NR>1 {print $1, $5}' | sed 's/.*://'
}

# List of commonly unnecessary ports (including port ranges)
UNNECESSARY_PORTS=("23" "21" "69" "515" "445" "2049" "6000-6063" "111")

# Function to check and close unnecessary ports
function check_and_close_ports {
    echo -e "\nUnnecessary ports identified: ${UNNECESSARY_PORTS[*]}"
    echo "Checking if these ports are open..."
    for PORT in "${UNNECESSARY_PORTS[@]}"; do
        if [[ $PORT =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Handle port range
            for i in `seq ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}`; do
                if ss -tuln | grep -q ":$i "; then
                    echo "Port $i is open."
                    read -p "Do you want to block this port? (yes/no): " RESPONSE
                    if [[ $RESPONSE == "yes" ]]; then
                        sudo iptables -A INPUT -p tcp --dport $i -j DROP
                        echo "Port $i has been blocked."
                    else
                        echo "Port $i left open."
                    fi
                else
                    echo "Port $i is not open."
                fi
            done
        else
            # Handle individual port
            if ss -tuln | grep -q ":$PORT "; then
                echo "Port $PORT is open."
                read -p "Do you want to block this port? (yes/no): " RESPONSE
                if [[ $RESPONSE == "yes" ]]; then
                    sudo iptables -A INPUT -p tcp --dport $PORT -j DROP
                    echo "Port $PORT has been blocked."
                else
                    echo "Port $PORT left open."
                fi
            else
                echo "Port $PORT is not open."
            fi
        fi
    done
}

# Function to display open ports with descriptions
function describe_ports {
    echo -e "\nDescriptions of common unnecessary ports:"
    echo "23  - Telnet (unsecured remote access)"
    echo "21  - FTP (unsecured file transfer)"
    echo "69  - TFTP (Trivial File Transfer Protocol)"
    echo "515 - LPD (Line Printer Daemon)"
    echo "445 - SMB (Server Message Block, file sharing)"
    echo "2049 - NFS (Network File System)"
    echo "6000-6063 - X11 (Graphical display forwarding)"
    echo "111 - RPC (Remote Procedure Call)"
}

# Main script logic
check_open_ports
describe_ports
check_and_close_ports

echo -e "\nAll operations completed. Review your firewall rules if necessary."