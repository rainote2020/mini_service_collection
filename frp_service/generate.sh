#!/bin/bash

# 检查参数
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <remote_ip> <remote_port>"
    echo "Example: $0 1.2.3.4 7000"
    exit 1
fi

REMOTE_IP=$1
REMOTE_PORT=$2
LOCAL_SSH_PORT=22
REMOTE_SSH_PORT=7000  # 远程SSH转发端口

# 创建必要的目录
mkdir -p frp

# 下载最新版本的frp
echo "Downloading latest frp..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
ARCH="amd64"
OS="linux"
FRP_FILENAME="frp_${LATEST_VERSION#v}_${OS}_${ARCH}"
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${LATEST_VERSION}/${FRP_FILENAME}.tar.gz"

wget -q $DOWNLOAD_URL -O frp.tar.gz
tar zxf frp.tar.gz
mv $FRP_FILENAME/* frp/
rm -rf $FRP_FILENAME frp.tar.gz

# 创建frpc配置文件
cat > frp/frpc.toml << EOF
[common]
server_addr = ${REMOTE_IP}
server_port = ${REMOTE_PORT}

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = ${LOCAL_SSH_PORT}
remote_port = ${REMOTE_SSH_PORT}
EOF

# 生成服务文件
SERVICE_NAME="frpc"
SERVICE_FILE="${SERVICE_NAME}.service"
INSTALL_SCRIPT="install_${SERVICE_NAME}.sh"
UNINSTALL_SCRIPT="uninstall_${SERVICE_NAME}.sh"

# 获取当前目录的绝对路径
CURRENT_DIR=$(pwd)

# 生成服务文件
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

# 生成安装脚本
cat > "$INSTALL_SCRIPT" << EOF
#!/bin/bash
if [ "\$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# 复制服务文件到系统目录
cp "$SERVICE_FILE" /etc/systemd/system/

# 重新加载systemd配置
systemctl daemon-reload

# 启用并启动服务
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

echo "$SERVICE_NAME service has been installed and started."
echo "Your SSH tunnel is now accessible at ${REMOTE_IP}:${REMOTE_SSH_PORT}"
EOF

# 生成卸载脚本
cat > "$UNINSTALL_SCRIPT" << EOF
#!/bin/bash
if [ "\$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# 停止并禁用服务
systemctl stop $SERVICE_NAME
systemctl disable $SERVICE_NAME

# 删除服务文件
rm -f /etc/systemd/system/$SERVICE_FILE

# 重新加载systemd配置
systemctl daemon-reload

echo "$SERVICE_NAME service has been uninstalled."
EOF

# 设置执行权限
chmod +x "$INSTALL_SCRIPT"
chmod +x "$UNINSTALL_SCRIPT"
chmod +x frp/frpc

echo "Generated files and configurations:"
echo "1. ${SERVICE_FILE} - Service unit file"
echo "2. ${INSTALL_SCRIPT} - Installation script"
echo "3. ${UNINSTALL_SCRIPT} - Uninstallation script"
echo "4. frp/frpc.ini - FRP client configuration"
echo
echo "To install the service, run: sudo ./${INSTALL_SCRIPT}"
echo "After installation, your SSH service will be accessible at ${REMOTE_IP}:${REMOTE_SSH_PORT}"
