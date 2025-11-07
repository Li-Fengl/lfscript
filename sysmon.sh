#!/bin/bash

# 获取 CPU 利用率
get_cpu_usage() {
    local idle1=$(grep 'cpu ' /proc/stat | awk '{print $5}')
    local total1=$(grep 'cpu ' /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    sleep 1
    local idle2=$(grep 'cpu ' /proc/stat | awk '{print $5}')
    local total2=$(grep 'cpu ' /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    local idle=$((idle2 - idle1))
    local total=$((total2 - total1))
    local usage=$((100 * (total - idle) / total))
    echo "CPU Usage: $usage%"
}

# 获取内存使用率
get_mem_usage() {
    local total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local free=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local used=$((total - free))
    local usage=$((100 * used / total))
    echo "Memory Usage: $usage%"
}

# 获取网络带宽使用情况
get_network_bandwidth() {
    local interface=$(ip route | awk '/default/ {print $5; exit}')
    local rx1=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx1=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    sleep 1
    local rx2=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx2=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    local rx_rate=$(((rx2 - rx1) / 1024))  # KB/s
    local tx_rate=$(((tx2 - tx1) / 1024))  # KB/s
    echo "Network Upload: $tx_rate KB/s"
    echo "Network Download: $rx_rate KB/s"
}

# 主函数
main() {
    get_cpu_usage
    get_mem_usage
    get_network_bandwidth
}

main
