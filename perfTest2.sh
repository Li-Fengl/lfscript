#!/bin/bash

# Linux性能测试工具v2.0
# 优化内容：精确速度计算 | 自动单位转换 | 增强错误处理

export LC_ALL=C  # 强制使用英文输出格式

# 颜色输出配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 测试参数
TEST_FILE="./.io_test.tmp"
DEFAULT_DISK_SIZE=1024    # 默认磁盘测试大小(MB)
DEFAULT_BLOCK_SIZE="1M"   # 默认块大小
DEFAULT_MEM_SIZE=500      # 内存测试大小(MB)
WARMUP_LOOPS=3            # CPU预热次数

# 异常处理
trap 'cleanup; exit 1' SIGINT SIGTERM ERR
cleanup() {
    rm -f "$TEST_FILE" "/dev/shm/memtest.tmp" 2>/dev/null
    echo -e "\n${RED}测试终止，临时文件已清理${NC}" >&2
}

# 单位转换函数
format_speed() {
    local speed=$1
    if (( $(echo "$speed >= 1024" | bc -l) )); then
        echo "$(echo "scale=2; $speed/1024" | bc) GB/s"
    else
        echo "$(echo "scale=2; $speed" | bc) MB/s"
    fi
}

# 精确解析dd输出
parse_dd_speed() {
    local dd_output="$1"
    local dd_line=$(echo "$dd_output" | tail -n 1)
    IFS=' ' read -ra parts <<< "${dd_line//,/}"  # 移除逗号
    
    local bytes=${parts[0]}
    local time=${parts[7]}
    local speed=$(echo "scale=2; $bytes/1024/1024/$time" | bc)
    
    echo "$speed"
}
# 新增单位转换函数
block_size_to_mb() {
    local block_size=$1
    local unit=$(echo "$block_size" | tr -d '0-9')
    local value=$(echo "$block_size" | tr -cd '0-9')

    case $(echo "$unit" | tr '[:lower:]' '[:upper:]') in
        K) echo "scale=10; $value / 1024" | bc ;;
        M) echo "$value" ;;
        G) echo "$value * 1024" | bc ;;
        *) echo "$value" ;; # 无单位默认MB
    esac
}
# 磁盘测试
disk_test() {
    echo -e "\n${YELLOW}▶ 磁盘IO测试${NC} (文件: ${DISK_SIZE}MB, 块: ${BLOCK_SIZE})"
    
    local block_size_mb=$(block_size_to_mb "$BLOCK_SIZE")
    local count=$(echo "$DISK_SIZE / $block_size_mb" | bc)
    
    # 保证至少写入1个块
    if (( $(echo "$count < 1" | bc -l) )); then
        count=1
    fi

    # 写入测试
    local write_output=$(dd if=/dev/zero of="$TEST_FILE" bs=${BLOCK_SIZE} \
        count=$count oflag=direct 2>&1)
    local write_speed=$(parse_dd_speed "$write_output")
    echo -e "写入速度: ${GREEN}$(format_speed $write_speed)${NC}"
    
    # 读取测试
    local read_output=$(dd if="$TEST_FILE" of=/dev/null bs=${BLOCK_SIZE} \
        iflag=direct 2>&1)
    local read_speed=$(parse_dd_speed "$read_output")
    echo -e "读取速度: ${GREEN}$(format_speed $read_speed)${NC}"
    
    rm -f "$TEST_FILE"
}

# 内存测试
memory_test() {
    echo -e "\n${YELLOW}▶ 内存速度测试${NC} (数据量: ${MEM_SIZE}MB)"
    local mem_file="/dev/shm/memtest.tmp"
    
    # 写入测试
    local write_output=$(dd if=/dev/zero of=$mem_file bs=1M count=$MEM_SIZE 2>&1)
    local write_speed=$(parse_dd_speed "$write_output")
    echo -e "内存写入: ${GREEN}$(format_speed $write_speed)${NC}"
    
    # 读取测试
    local read_output=$(dd if=$mem_file of=/dev/null bs=1M 2>&1)
    local read_speed=$(parse_dd_speed "$read_output")
    echo -e "内存读取: ${GREEN}$(format_speed $read_speed)${NC}"
    
    rm -f $mem_file
}

# CPU测试
cpu_test() {
    echo -e "\n${YELLOW}▶ CPU性能测试${NC} (计算π精度: 10000位)"
    
    # 预热CPU
    for ((i=0; i<WARMUP_LOOPS; i++)); do
        echo "scale=1000; 4*a(1)" | bc -lq >/dev/null
    done
    
    # 正式测试
    local start_time=$(date +%s.%N)
    echo "scale=10000; 4*a(1)" | bc -lq >/dev/null
    local total_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    echo -e "计算耗时: ${GREEN}$(printf "%.2f" $total_time)s${NC}"
    echo -e "性能评分: ${GREEN}$(echo "scale=2; 100/$total_time" | bc)${NC} (数值越大越好)"
}

# 参数解析
while getopts "dms:b:hc" opt; do
    case $opt in
        d) NO_DISK=true ;;
        m) NO_MEM=true ;;
        c) NO_CPU=true ;;
        s) DISK_SIZE=$OPTARG ;;
        b) BLOCK_SIZE=$OPTARG ;;
        h) echo -e "使用说明:\n  -d 禁用磁盘测试\n  -m 禁用内存测试\n  -c 禁用CPU测试\n  -s 磁盘测试大小(MB)\n  -b 块大小(如1M)"; exit 0 ;;
        *) cleanup; exit 1 ;;
    esac
done

# 参数初始化
DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
BLOCK_SIZE=${BLOCK_SIZE:-$DEFAULT_BLOCK_SIZE}
MEM_SIZE=${MEM_SIZE:-$DEFAULT_MEM_SIZE}

# 参数验证
[[ "$DISK_SIZE" =~ ^[0-9]+$ ]] || { echo -e "${RED}错误: 磁盘大小必须为整数${NC}"; exit 1; }
[[ "$BLOCK_SIZE" =~ ^[0-9]+[MGK]?$ ]] || { echo -e "${RED}错误: 块大小格式错误${NC}"; exit 1; }

# 执行测试
echo -e "${GREEN}当前测试配置："
echo "磁盘测试: ${DISK_SIZE}MB | 内存测试: ${MEM_SIZE}MB | 块大小: ${BLOCK_SIZE}"
echo -e "=======================================${NC}"

[[ -z $NO_DISK ]] && disk_test
[[ -z $NO_MEM ]] && memory_test
[[ -z $NO_CPU ]] && cpu_test

echo -e "\n${GREEN}✓ 所有测试已完成${NC}"