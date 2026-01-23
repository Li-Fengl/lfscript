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

ZAB_HOST=$(curl -s ip.sb)
# 检测 CentOS 版本
if grep -q "release 7" /etc/redhat-release; then
    OS_VER="7"
    PKG_TOOL="yum"
elif grep -q "release 8" /etc/redhat-release || grep -q "Stream release 8" /etc/redhat-release; then
    OS_VER="8"
    PKG_TOOL="dnf"
else
    echo "X 不支持的 CentOS 版本"
    exit 1
fi

echo "检测到 CentOS ${OS_VER}, 使用 ${PKG_TOOL}"

# 添加 Zabbix 仓库
rpm -Uvh https://repo.zabbix.com/zabbix/${ZBX_VER}/rhel/${OS_VER}/x86_64/zabbix-release-${ZBX_VER}-1.el${OS_VER}.noarch.rpm

# 清理并安装 agent2
${PKG_TOOL} clean all
${PKG_TOOL} makecache
${PKG_TOOL} install -y zabbix-agent2 zabbix-agent2-plugin-*

# 配置 zabbix_agent2.conf
sed -i "s/^Server=.*/Server=${ZBX_SERVER_IP}/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^ServerActive=.*/ServerActive=${ZBX_SERVER_IP}/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^Hostname=.*/Hostname=${ZAB_HOST}/" /etc/zabbix/zabbix_agent2.conf
echo "BufferSend=10" >> /etc/zabbix/zabbix_agent2.conf
echo "BufferSize=1500" >> /etc/zabbix/zabbix_agent2.conf
# 自动注册所需的 HostMetadata
if ! grep -q "^HostMetadata=" /etc/zabbix/zabbix_agent2.conf; then
    echo "HostMetadata=${ZBX_METADATA}" >> /etc/zabbix/zabbix_agent2.conf
else
    sed -i "s/^HostMetadata=.*/HostMetadata=${ZBX_METADATA}/" /etc/zabbix/zabbix_agent2.conf
fi

# 启动并设置开机启动
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

# 状态检查
systemctl status zabbix-agent2 --no-pager
