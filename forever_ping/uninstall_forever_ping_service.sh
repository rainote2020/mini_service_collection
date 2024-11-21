#!/bin/bash

# uninstall_forever_ping.sh
# 卸载 forever_ping 服务

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用root权限运行此脚本。"
  exit 1
fi

# 停止服务
systemctl stop forever_ping.service

# 禁用服务
systemctl disable forever_ping.service

# 移除服务文件
rm -f /etc/systemd/system/forever_ping.service

# 移除 ping 脚本
rm -f /usr/local/bin/forever_ping.sh

# 重新加载 systemd 配置
systemctl daemon-reload

echo "forever_ping 服务已成功卸载。"

