#!/bin/bash

# install_forever_ping.sh
# 安装 forever_ping 服务

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用root权限运行此脚本。"
  exit 1
fi

# 提示用户输入 IP 地址
read -p "请输入希望 ping 的 IP 地址: " IP

# 简单的 IP 格式验证
if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "无效的 IP 地址格式。"
  exit 1
fi

# 创建 forever_ping.sh 脚本
cat << EOF > /usr/local/bin/forever_ping.sh
#!/bin/bash

# forever_ping.sh
# 持续 ping 指定的 IP 地址

IP_ADDRESS="$IP"

if [ -z "\$IP_ADDRESS" ]; then
  echo "Usage: \$0 <IP_ADDRESS>"
  exit 1
fi

while true
do
  ping -c 4 "\$IP_ADDRESS"
  sleep 60  # 每隔60秒 ping 一次
done
EOF

# 赋予脚本执行权限
chmod +x /usr/local/bin/forever_ping.sh

# 创建 systemd 服务文件
cat << EOF > /etc/systemd/system/forever_ping.service
[Unit]
Description=Forever Ping Service
After=network.target

[Service]
ExecStart=/usr/local/bin/forever_ping.sh $IP
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置
systemctl daemon-reload

# 启动并启用服务
systemctl start forever_ping.service
systemctl enable forever_ping.service

echo "forever_ping 服务已安装并启动，正在持续 ping IP: $IP"

