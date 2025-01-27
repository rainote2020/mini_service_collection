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
    show_help
    exit 1
}

# Detect system architecture
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*|armv6*|arm*)
            echo "arm"
            ;;
        *)
            error_exit "Unsupported architecture: $arch\nOnly amd64, arm64, and arm are supported"
            ;;
    esac
}

# Detect operating system
detect_os() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$os" in
        linux)
            echo "linux"
            ;;
        *)
            error_exit "Unsupported operating system: $os\nOnly Linux is supported"
            ;;
    esac
}

# Set default values
LOCAL_SSH_PORT=22
REMOTE_SSH_PORT=6000

# Show help information
show_help() {
    echo -e "${BLUE}Usage: $0 -s server_ip -p server_port [-l local_port] [-r remote_port]${NC}"
    echo -e "${YELLOW}Options:${NC}"
    echo "  -s: FRP server IP address (required)"
    echo "  -p: FRP server port (required)"
    echo "  -l: Local SSH port (default: 22)"
    echo "  -r: Remote mapping port (default: 6000)"
    echo "  -h: Show this help message"
    exit 0
}

# Parse parameters
while getopts "s:p:l:r:h" opt; do
    case $opt in
        s) REMOTE_IP="$OPTARG";;
        p) REMOTE_PORT="$OPTARG";;
        l) LOCAL_SSH_PORT="$OPTARG";;
        r) REMOTE_SSH_PORT="$OPTARG";;
        h) show_help;;
        \?) error_exit "Invalid option: -$OPTARG";;
        :) error_exit "Option -$OPTARG requires an argument";;
    esac
done

# Check required parameters
if [ -z "$REMOTE_IP" ] || [ -z "$REMOTE_PORT" ]; then
    error_exit "Server IP and port are required"
fi

# Validate port number
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error_exit "Invalid port number: $port"
    fi
}

validate_port "$REMOTE_PORT"
validate_port "$LOCAL_SSH_PORT"
validate_port "$REMOTE_SSH_PORT"

# Validate IP address
if ! [[ "$REMOTE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error_exit "Invalid IP address: $REMOTE_IP"
fi

echo -e "${BLUE}Configuration Info:${NC}"
echo -e "${GREEN}Server IP: ${NC}$REMOTE_IP"
echo -e "${GREEN}Server Port: ${NC}$REMOTE_PORT"
echo -e "${GREEN}Local SSH Port: ${NC}$LOCAL_SSH_PORT"
echo -e "${GREEN}Remote Port: ${NC}$REMOTE_SSH_PORT"
echo

# Create necessary directory
mkdir -p frp

# Download latest version of frp
echo -e "${BLUE}Downloading latest FRP...${NC}"
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
ARCH=$(detect_arch)
OS=$(detect_os)
FRP_FILENAME="frp_${LATEST_VERSION#v}_${OS}_${ARCH}"
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${LATEST_VERSION}/${FRP_FILENAME}.tar.gz"

wget -q $DOWNLOAD_URL -O frp.tar.gz || error_exit "Failed to download FRP"
tar zxf frp.tar.gz || error_exit "Failed to extract FRP"
mv $FRP_FILENAME/* frp/
rm -rf $FRP_FILENAME frp.tar.gz

# Create frpc configuration file
cat > frp/frpc.toml << EOF
serverAddr = "${REMOTE_IP}"
serverPort = ${REMOTE_PORT}

[[proxies]]
name = "ssh-tunnel"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${LOCAL_SSH_PORT}
remotePort = ${REMOTE_SSH_PORT}
EOF

# Generate service file
SERVICE_NAME="frpc"
SERVICE_FILE="${SERVICE_NAME}.service"
INSTALL_SCRIPT="install_${SERVICE_NAME}.sh"
UNINSTALL_SCRIPT="uninstall_${SERVICE_NAME}.sh"

# Get current directory absolute path
CURRENT_DIR=$(pwd)

# Generate service file
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
ExecStart=${CURRENT_DIR}/frp/frpc -c ${CURRENT_DIR}/frp/frpc.toml
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
    echo -e "\033[0;31mPlease run as root\033[0m"
    exit 1
fi

# Copy service file to system directory
cp "$SERVICE_FILE" /etc/systemd/system/

# Reload systemd configuration
systemctl daemon-reload

# Enable and start service
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

echo -e "\033[0;32m$SERVICE_NAME service has been installed and started.\033[0m"
echo -e "\033[0;32mSSH tunnel is accessible at: ${REMOTE_IP}:${REMOTE_SSH_PORT}\033[0m"
EOF

# Generate uninstallation script
cat > "$UNINSTALL_SCRIPT" << EOF
#!/bin/bash
if [ "\$(id -u)" -ne 0 ]; then
    echo -e "\033[0;31mPlease run as root\033[0m"
    exit 1
fi

# Stop and disable service
systemctl stop $SERVICE_NAME
systemctl disable $SERVICE_NAME

# Remove service file
rm -f /etc/systemd/system/$SERVICE_FILE

# Reload systemd configuration
systemctl daemon-reload

echo -e "\033[0;32m$SERVICE_NAME service has been uninstalled.\033[0m"
EOF

# Set execution permissions
chmod +x "$INSTALL_SCRIPT"
chmod +x "$UNINSTALL_SCRIPT"
chmod +x frp/frpc

echo -e "${BLUE}Generated files and configurations:${NC}"
echo -e "${GREEN}1. ${SERVICE_FILE}${NC} - Service unit file"
echo -e "${GREEN}2. ${INSTALL_SCRIPT}${NC} - Installation script"
echo -e "${GREEN}3. ${UNINSTALL_SCRIPT}${NC} - Uninstallation script"
echo -e "${GREEN}4. frp/frpc.toml${NC} - FRP client configuration"
echo
echo -e "${YELLOW}To install the service, run: ${NC}sudo ./${INSTALL_SCRIPT}"
echo -e "${YELLOW}After installation, your SSH service will be accessible at: ${NC}${REMOTE_IP}:${REMOTE_SSH_PORT}"
