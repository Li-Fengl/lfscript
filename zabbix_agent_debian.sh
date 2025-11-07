#!/bin/bash

ZBX_VER="6.0"
ZBX_SERVER_IP=$1  # 修改为你的 Zabbix Server IP

# 添加仓库
wget https://repo.zabbix.com/zabbix/${ZBX_VER}/debian/pool/main/z/zabbix-release/zabbix-release_${ZBX_VER}-1+debian12_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb

# 安装 agent
apt update
apt install -y zabbix-agent

# 配置 zabbix_agentd.conf
sed -i "s/^Server=127.0.0.1/Server=${ZBX_SERVER_IP}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=127.0.0.1/ServerActive=${ZBX_SERVER_IP}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# 启动并设置开机启动
systemctl enable zabbix-agent
systemctl restart zabbix-agent

# 状态检查
systemctl status zabbix-agent
