#!/bin/bash

ZBX_VER="6.0"
ZBX_SERVER_IP="45.126.180.162"  # 修改为你的 Zabbix Server IP

# 检测 CentOS 版本
if grep -q "release 7" /etc/redhat-release; then
    OS_VER="7"
elif grep -q "release 8" /etc/redhat-release; then
    OS_VER="8"
else
    echo "不支持的 CentOS 版本"
    exit 1
fi

# 添加 Zabbix 仓库
rpm -Uvh https://repo.zabbix.com/zabbix/${ZBX_VER}/rhel/${OS_VER}/x86_64/zabbix-release-${ZBX_VER}-1.el${OS_VER}.noarch.rpm

# 安装 agent
dnf clean all || yum clean all
dnf install -y zabbix-agent || yum install -y zabbix-agent

# 配置 zabbix_agentd.conf
sed -i "s/^Server=127.0.0.1/Server=${ZBX_SERVER_IP}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=127.0.0.1/ServerActive=${ZBX_SERVER_IP}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# 启动并设置开机启动
systemctl enable zabbix-agent
systemctl restart zabbix-agent

# 状态检查
systemctl status zabbix-agent
