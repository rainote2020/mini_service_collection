#!/bin/bash

# 定义错误处理函数
error_exit() {
    echo "错误: $1" >&2
    exit 1
}

# 设置默认值
LOCAL_SSH_PORT=22
REMOTE_SSH_PORT=6000

# 显示帮助信息
show_help() {
    echo "Usage: $0 -s server_ip -p server_port [-l local_port] [-r remote_port]"
    echo "Options:"
    echo "  -s: FRP服务器IP地址（必需）"
    echo "  -p: FRP服务器端口（必需）"
    echo "  -l: 本地SSH端口（默认22）"
    echo "  -r: 远程映射端口（默认6000）"
    echo "  -h: 显示帮助信息"
    exit 0
}

# 参数解析
while getopts "s:p:l:r:h" opt; do
    case $opt in
        s) REMOTE_IP="$OPTARG";;
        p) REMOTE_PORT="$OPTARG";;
        l) LOCAL_SSH_PORT="$OPTARG";;
        r) REMOTE_SSH_PORT="$OPTARG";;
        h) show_help;;
        \?) error_exit "无效的选项: -$OPTARG";;
        :) error_exit "选项 -$OPTARG 需要参数";;
    esac
done

# 检查必需参数
if [ -z "$REMOTE_IP" ] || [ -z "$REMOTE_PORT" ]; then
    error_exit "服务器IP和端口是必需的参数\n使用 -h 查看帮助信息"
fi

# 验证端口号
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error_exit "无效的端口号: $port"
    fi
}

validate_port "$REMOTE_PORT"
validate_port "$LOCAL_SSH_PORT"
validate_port "$REMOTE_SSH_PORT"

# 验证IP地址
if ! [[ "$REMOTE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error_exit "无效的IP地址: $REMOTE_IP"
fi

echo "配置信息："
echo "服务器IP: $REMOTE_IP"
echo "服务器端口: $REMOTE_PORT"
echo "本地SSH端口: $LOCAL_SSH_PORT"
echo "远程映射端口: $REMOTE_SSH_PORT"
echo

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
serverAddr = "${REMOTE_IP}"
serverPort = ${REMOTE_PORT}

[[proxies]]
name = "ssh-tunnel"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${LOCAL_SSH_PORT}
remotePort = ${REMOTE_SSH_PORT}
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
echo "4. frp/frpc.toml - FRP client configuration"
echo
echo "To install the service, run: sudo ./${INSTALL_SCRIPT}"
echo "After installation, your SSH service will be accessible at ${REMOTE_IP}:${REMOTE_SSH_PORT}"
