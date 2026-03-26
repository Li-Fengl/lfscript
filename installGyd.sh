#!/bin/bash

# 启用严格模式
set -euo pipefail

# 定义颜色代码
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 日志函数
info() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}
error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}
# 检查root权限
check_root
# 安装依赖
info 安装依赖
yum install libnetfilter_queue -y
# 下载脚本
curl -L -o /root/iptable56 https://github.com/Li-Fengl/lfscript/releases/download/gyd/iptable56 || error 下载失败
cd /root
chmod +x ./iptable56
cat > /etc/systemd/system/iptable56.service << EOF
[Unit]
Description=iptable56 Service
After=network.target iptables.service

[Service]
Type=simple
ExecStart=/bin/sh -c "/root/iptable56 > /root/iptable56.log 2>&1"
Restart=always
RestartSec=2
CapabilityBoundingSet=CAP_NET_ADMIN

[Install]
WantedBy=multi-user.target
EOF

info "重新加载systemd配置"
systemctl daemon-reload || error "systemd配置重载失败"
info "重启日志服务"
systemctl restart systemd-journald || error "journald服务重启失败"
info "启动节点过屏蔽管理"
systemctl enable --now iptable56 || error "服务启用启动失败"
info 添加规则
iptables -I OUTPUT -p tcp --sport 443 --tcp-flags SYN,RST,ACK,FIN,PSH SYN,ACK -j NFQUEUE --queue-num 6 || error 443规则添加失败
iptables -I OUTPUT -p tcp --sport 80 -j NFQUEUE --queue-num 80 --queue-bypass || error 80规则添加失败
iptables -L -n -v
# 下载脚本
curl -L https://github.com/Li-Fengl/lfscript/raw/refs/heads/script/1/QHYD2 -o /opt/QHYD2
chmod +x /opt/QHYD2
/opt/QHYD2 -q 80 -w 5 -c 3
systemctl status iptable56
systemctl status CDNK
