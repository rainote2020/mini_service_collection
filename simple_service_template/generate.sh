#!/bin/bash

# 检查参数
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <service_name> <command>"
    echo "Example: $0 myservice '/usr/local/bin/myapp'"
    exit 1
fi

SERVICE_NAME=$1
COMMAND=$2
SERVICE_FILE="${SERVICE_NAME}.service"
INSTALL_SCRIPT="install_${SERVICE_NAME}.sh"
UNINSTALL_SCRIPT="uninstall_${SERVICE_NAME}.sh"

# 生成服务文件
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=$SERVICE_NAME
After=network.target

[Service]
ExecStart=$COMMAND
Restart=always
User=nobody

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

echo "Generated files:"
echo "1. $SERVICE_FILE - Service unit file"
echo "2. $INSTALL_SCRIPT - Installation script"
echo "3. $UNINSTALL_SCRIPT - Uninstallation script"
