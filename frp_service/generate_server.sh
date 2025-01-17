#!/bin/bash

# 检查参数
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <bind_port> <dashboard_port>"
    echo "Example: $0 7000 7850"
    exit 1
fi

BIND_PORT=$1
DASHBOARD_PORT=$2

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

# 创建frps配置文件
cat > frp/frps.toml << EOF
bindPort = ${BIND_PORT}
[webServer]
addr = "0.0.0.0"
port = ${DASHBOARD_PORT}
user = "admin"
password = "admin"
EOF

# 生成服务文件
SERVICE_NAME="frps"
SERVICE_FILE="${SERVICE_NAME}.service"
INSTALL_SCRIPT="install_${SERVICE_NAME}.sh"
UNINSTALL_SCRIPT="uninstall_${SERVICE_NAME}.sh"

# 获取当前目录的绝对路径
CURRENT_DIR=$(pwd)

# 生成服务文件
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=frp server
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
echo "FRP Server is listening on port ${BIND_PORT}"
echo "Dashboard is accessible at http://0.0.0.0:${DASHBOARD_PORT}"
echo "Dashboard credentials: admin/admin"
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
chmod +x frp/frps

echo "Generated files and configurations:"
echo "1. ${SERVICE_FILE} - Service unit file"
echo "2. ${INSTALL_SCRIPT} - Installation script"
echo "3. ${UNINSTALL_SCRIPT} - Uninstallation script"
echo "4. frp/frps.toml - FRP server configuration"
echo
echo "To install the service, run: sudo ./${INSTALL_SCRIPT}"
echo "After installation:"
echo "- FRP Server will be listening on port ${BIND_PORT}"
echo "- Dashboard will be accessible at http://0.0.0.0:${DASHBOARD_PORT}"
echo "- Dashboard credentials: admin/admin"
