#!/bin/bash

ZBX_VER="6.0"

# 用法检查：必须提供两个参数
if [ $# -ne 2 ]; then
    echo "用法: $0 <ZBX_SERVER_IP> <ZBX_METADATA>"
    echo "示例: $0 192.168.1.100 web-prod-01"
    exit 1
fi

# 将参数赋值给变量
ZBX_SERVER_IP="$1"
ZBX_METADATA="$2"

# 检查是否为空（包括只传了空字符串的情况）
if [ -z "$ZBX_SERVER_IP" ]; then
    echo "错误: ZBX_SERVER_IP 不能为空"
    exit 1
fi

if [ -z "$ZBX_METADATA" ]; then
    echo "错误: ZBX_METADATA 不能为空"
    exit 1
fi

# 检测 Debian / Ubuntu
if grep -qi "debian" /etc/os-release; then
    OS_ID="debian"
    OS_VER=$(grep -oP 'VERSION_ID="\K[0-9]+' /etc/os-release)
elif grep -qi "ubuntu" /etc/os-release; then
    OS_ID="ubuntu"
    OS_VER=$(grep -oP 'VERSION_ID="\K[0-9]+' /etc/os-release)
else
    echo "X 仅支持 Debian/Ubuntu"
    exit 1
fi

echo "Detected: ${OS_ID} ${OS_VER}"

apt update -y
apt install -y wget curl gnupg lsb-release

# 自动找到最新的 zabbix-release_*.deb
echo "获取最新 Zabbix 仓库包..."

DEB_URL=$(wget -qO- https://repo.zabbix.com/zabbix/${ZBX_VER}/${OS_ID}/pool/main/z/zabbix-release/ \
    | grep -oP "zabbix-release_${ZBX_VER}-[0-9]+\\+${OS_ID}${OS_VER}_all\\.deb" \
    | sort -V | tail -n 1)

if [[ -z "$DEB_URL" ]]; then
    echo "X 未找到 zabbix-release 包，请检查路径："
    echo "https://repo.zabbix.com/zabbix/${ZBX_VER}/${OS_ID}/pool/main/z/zabbix-release/"
    exit 1
fi

echo "最新包名：$DEB_URL"

wget https://repo.zabbix.com/zabbix/${ZBX_VER}/${OS_ID}/pool/main/z/zabbix-release/$DEB_URL
dpkg -i $DEB_URL

apt update -y
apt install -y zabbix-agent2 zabbix-agent2-plugin-*

CONF="/etc/zabbix/zabbix_agent2.conf"

sed -i "s/^Server=.*/Server=${ZBX_SERVER_IP}/" $CONF
sed -i "s/^ServerActive=.*/ServerActive=${ZBX_SERVER_IP}/" $CONF
sed -i "s/^Hostname=.*/Hostname=$(hostname)/" $CONF

# HostMetadata 设置
grep -q "^HostMetadata=" $CONF \
  && sed -i "s/^HostMetadata=.*/HostMetadata=${ZBX_METADATA}/" $CONF \
  || echo "HostMetadata=${ZBX_METADATA}" >> $CONF
echo "BufferSend=5" >> /etc/zabbix/zabbix_agent2.conf
echo "BufferSize=1000" >> /etc/zabbix/zabbix_agent2.conf
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2
systemctl status zabbix-agent2 --no-pager
