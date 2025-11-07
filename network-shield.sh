#!/bin/bash
# Linux Network Shield v1.2
# 功能：自动检测异常连接，封禁可疑IP，支持多种防火墙后端

# 初始化配置
THRESHOLD=100      # 单个IP最大连接数阈值
BAN_TIME="24h"     # 封禁持续时间
PORTS="22,80,443"  # 监控的重点端口
WHITELIST=(127.0.0.1 192.168.0.0/16 10.0.0.0/8) # IP白名单
LOG_FILE="/var/log/network_shield.log"

# 检测可用防火墙后端
detect_firewall() {
    if command -v iptables >/dev/null 2>&1 && [ -d /etc/iptables ]; then
        echo "iptables"
    elif command -v ufw >/dev/null 2>&1 && [ -d /etc/ufw ]; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1 && [ -d /etc/firewalld ]; then
        echo "firewalld"
    else
        echo "unknown"
    fi
}

# 防火墙命令封装
ban_ip() {
    local ip=$1
    case $FIREWALL in
        iptables)
            iptables -A INPUT -s $ip -j DROP
            iptables-save > /etc/iptables/rules.v4
            ;;
        ufw)
            ufw deny from $ip
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' reject"
            firewall-cmd --reload
            ;;
    esac
}

# 日志记录
log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# 主检测逻辑
main() {
    FIREWALL=$(detect_firewall)
    echo "当前防火墙后端: $FIREWALL"
    
    # 获取连接统计
    ss -ntu | awk '{print $6}' | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | \
        sort | uniq -c | sort -nr | while read count ip; do
            
        # 跳过白名单IP
        for white_ip in "${WHITELIST[@]}"; do
            if [[ $ip == $white_ip || $(ipcalc -n $ip $white_ip 2>/dev/null) ]]; then
                continue 2
            fi
        done

        # 阈值检测
        if [ $count -gt $THRESHOLD ]; then
            if ! grep -q $ip $LOG_FILE; then
                log_event "封禁IP: $ip 连接数: $count"
                ban_ip $ip
            fi
        fi
    done
}

# 执行入口
if [ "$(id -u)" != "0" ]; then
    echo "需要root权限运行"
    exit 1
fi

case "$1" in
    install)
        # 设置定时任务
        cp $0 /usr/local/bin/network-shield
        chmod +x /usr/local/bin/network-shield
        echo "*/5 * * * * root /usr/local/bin/network-shield run" > /etc/cron.d/network-shield
        echo "安装完成，已创建定时任务"
        ;;
    run)
        main
        ;;
    *)
        echo "用法: $0 [install|run]"
        echo "install - 安装为系统服务"
        echo "run - 立即执行检测"
        exit 1
        ;;
esac