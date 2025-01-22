#!/bin/bash

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define error handling function
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Show help information
show_help() {
    echo -e "${BLUE}Usage: $0 -p bind_port -d dashboard_port${NC}"
    echo -e "${YELLOW}Options:${NC}"
    echo "  -p: FRP server bind port (required)"
    echo "  -d: Dashboard port (required)"
    echo "  -h: Show this help message"
    exit 0
}

# Parse parameters
while getopts "p:d:h" opt; do
    case $opt in
        p) BIND_PORT="$OPTARG";;
        d) DASHBOARD_PORT="$OPTARG";;
        h) show_help;;
        \?) error_exit "Invalid option: -$OPTARG";;
        :) error_exit "Option -$OPTARG requires an argument";;
    esac
done

# Check required parameters
if [ -z "$BIND_PORT" ] || [ -z "$DASHBOARD_PORT" ]; then
    error_exit "Bind port and dashboard port are required\nUse -h to show help message"
fi

# Validate port number
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error_exit "Invalid port number: $port"
    fi
}

validate_port "$BIND_PORT"
validate_port "$DASHBOARD_PORT"

echo -e "${BLUE}Configuration Info:${NC}"
echo -e "${GREEN}Bind Port: ${NC}$BIND_PORT"
echo -e "${GREEN}Dashboard Port: ${NC}$DASHBOARD_PORT"
echo

# Create necessary directory
mkdir -p frp

# Download latest version of frp
echo -e "${BLUE}Downloading latest FRP...${NC}"
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
ARCH="amd64"
OS="linux"
FRP_FILENAME="frp_${LATEST_VERSION#v}_${OS}_${ARCH}"
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${LATEST_VERSION}/${FRP_FILENAME}.tar.gz"

wget -q $DOWNLOAD_URL -O frp.tar.gz || error_exit "Failed to download FRP"
tar zxf frp.tar.gz || error_exit "Failed to extract FRP"
mv $FRP_FILENAME/* frp/
rm -rf $FRP_FILENAME frp.tar.gz

# Create frps configuration file
cat > frp/frps.toml << EOF
bindPort = ${BIND_PORT}
[webServer]
addr = "0.0.0.0"
port = ${DASHBOARD_PORT}
user = "admin"
password = "admin"
EOF

# Generate service file
SERVICE_NAME="frps"
SERVICE_FILE="${SERVICE_NAME}.service"
INSTALL_SCRIPT="install_${SERVICE_NAME}.sh"
UNINSTALL_SCRIPT="uninstall_${SERVICE_NAME}.sh"

# Get current directory absolute path
CURRENT_DIR=$(pwd)

# Generate service file
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=FRP Server Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
ExecStart=${CURRENT_DIR}/frp/frps -c ${CURRENT_DIR}/frp/frps.toml
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# Generate installation script
cat > "$INSTALL_SCRIPT" << EOF
#!/bin/bash
if [ "\$(id -u)" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Copy service file to system directory
cp "$SERVICE_FILE" /etc/systemd/system/

# Reload systemd configuration
systemctl daemon-reload

# Enable and start service
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

echo -e "${GREEN}$SERVICE_NAME service has been installed and started.${NC}"
echo -e "${GREEN}FRP Server is listening on port ${BIND_PORT}${NC}"
echo -e "${GREEN}Dashboard is accessible at http://0.0.0.0:${DASHBOARD_PORT}${NC}"
echo -e "${YELLOW}Dashboard credentials: admin/admin${NC}"
EOF

# Generate uninstallation script
cat > "$UNINSTALL_SCRIPT" << EOF
#!/bin/bash
if [ "\$(id -u)" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Stop and disable service
systemctl stop $SERVICE_NAME
systemctl disable $SERVICE_NAME

# Remove service file
rm -f /etc/systemd/system/$SERVICE_FILE

# Reload systemd configuration
systemctl daemon-reload

echo -e "${GREEN}$SERVICE_NAME service has been uninstalled.${NC}"
EOF

# Set execution permissions
chmod +x "$INSTALL_SCRIPT"
chmod +x "$UNINSTALL_SCRIPT"
chmod +x frp/frps

echo -e "${BLUE}Generated files and configurations:${NC}"
echo -e "${GREEN}1. ${SERVICE_FILE}${NC} - Service unit file"
echo -e "${GREEN}2. ${INSTALL_SCRIPT}${NC} - Installation script"
echo -e "${GREEN}3. ${UNINSTALL_SCRIPT}${NC} - Uninstallation script"
echo -e "${GREEN}4. frp/frps.toml${NC} - FRP server configuration"
echo
echo -e "${YELLOW}To install the service, run: ${NC}sudo ./${INSTALL_SCRIPT}"
echo -e "${YELLOW}After installation:${NC}"
echo -e "- FRP Server will be listening on port ${BIND_PORT}"
echo -e "- Dashboard will be accessible at http://0.0.0.0:${DASHBOARD_PORT}"
echo -e "- Dashboard credentials: admin/admin"
