#!/bin/bash

# SMB Diagnostic Tool for Linux Clients
# Author: AI Assistant
# Description: Checks local SMB tools, services, and remote SMB connectivity
# Tested on: AlmaLinux, Ubuntu, Debian, RHEL, Fedora

set -e

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

# Helper: Print colored status
log() {
    local level="$1"
    local message="$2"
    case $level in
        INFO) echo -e "${BLUE}[INFO]${NC} $message" ;;
        OK) echo -e "${GREEN}[OK]${NC} $message" ;;
        WARN) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
}

# Check dependencies
check_tools() {
    log INFO "Checking required SMB tools..."
    for tool in smbclient mount.cifs nc; do
        TOOL_PATH=$(which "$tool" 2>/dev/null)
        if [[ -z "$TOOL_PATH" || ! -x "$TOOL_PATH" ]]; then
            log ERROR "Missing or not executable: $tool"
            echo -e "Attempted to locate '$tool' but it is either:\n- Not installed\n- Not executable\n- Not in your current PATH"
            echo -e "To fix this, try:\n  Debian/Ubuntu: sudo apt install $tool\n  RHEL/Fedora: sudo dnf install $tool"
            echo "PATH is: $PATH"
            exit 1
        else
            log OK "$tool found at: $TOOL_PATH"
        fi
    done
    log OK "All required tools are installed."
}

# Check local services (if applicable)
check_local_services() {
    for service in smbd nmbd winbind; do
        if systemctl list-units --type=service | grep -q "$service"; then
            if systemctl is-active --quiet "$service"; then
                log OK "$service is running"
            else
                log WARN "$service is installed but not running"
                echo "You can start it using: sudo systemctl start $service"
            fi
        fi
    done
}

# Prompt user for SMB server info
get_smb_details() {
    echo ""
    read -rp "Enter SMB server address (IP or hostname): " SMB_SERVER
    read -rp "Enter SMB share name: " SMB_SHARE

    read -rp "Use authentication? (y/n): " use_auth
    if [[ "$use_auth" == "y" || "$use_auth" == "Y" ]]; then
        read -rp "Username: " SMB_USER
        read -rsp "Password: " SMB_PASS
        echo ""
    fi
}

# Check if SMB port is reachable
check_remote_smb_port() {
    log INFO "Checking remote SMB port..."
    if nc -z -w3 "$SMB_SERVER" 445; then
        log OK "Port 445 is open on $SMB_SERVER"
    else
        log ERROR "Cannot reach port 445 on $SMB_SERVER"
        echo -e "Suggestions:\n- Check if the server is online\n- Ensure port 445 is open and not blocked by a firewall\n- Try pinging the server with: ping $SMB_SERVER"
        exit 1
    fi
}

# Authenticate and list shares (if user provided credentials)
check_authentication() {
    log INFO "Testing SMB authentication..."
    if [[ -n "$SMB_USER" && -n "$SMB_PASS" ]]; then
        smbclient -L "$SMB_SERVER" -U "$SMB_USER%$SMB_PASS" -m SMB3 -g | grep -q "^Disk" \
            && log OK "Authenticated successfully and found shared folders" \
            || {
                log ERROR "Authentication failed or no shares found"
                echo -e "Troubleshooting tips:\n- Double-check username/password\n- Ensure the user has access to the share\n- Try connecting manually: smbclient -L $SMB_SERVER -U $SMB_USER"
            }
    else
        smbclient -L "$SMB_SERVER" -N -m SMB3 -g | grep -q "^Disk" \
            && log OK "Guest access succeeded and found shared folders" \
            || {
                log ERROR "Guest access failed or no shares available"
                echo -e "Possible reasons:\n- Guest access is disabled on the server\n- No accessible shares are available\n- Try using authentication instead."
            }
    fi
}

# MAIN
echo -e "\n=== SMB Client Diagnostic ===\n"
check_tools
check_local_services
get_smb_details
check_remote_smb_port
check_authentication
echo -e "\n${GREEN}SMB diagnostics completed.${NC}\n"
