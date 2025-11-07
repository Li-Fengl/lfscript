#!/bin/bash

# 性能测试工具v1.0
# 支持测试：磁盘IO | 内存速度 | CPU计算能力

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 测试参数配置
TEST_FILE="./test_file.tmp"
DEFAULT_DISK_SIZE=1024  # 默认测试文件大小(MB)
DEFAULT_BLOCK_SIZE=1M   # 默认块大小
DEFAULT_MEM_SIZE=500    # 内存测试大小(MB)
WARMUP_LOOPS=3          # CPU预热次数

# 异常处理
trap 'cleanup; exit 1' SIGINT
cleanup() {
    rm -f "$TEST_FILE" 2>/dev/null
    echo -e "\n${RED}测试已中断，临时文件已清理${NC}"
}

# 显示帮助
usage() {
    echo -e "${GREEN}用法: $0 [选项]"
    echo "选项:"
    echo "  -d      禁用磁盘测试"
    echo "  -m      禁用内存测试"
    echo "  -c      禁用CPU测试"
    echo "  -s NUM  设置磁盘测试文件大小(MB) [默认: ${DEFAULT_DISK_SIZE}]"
    echo "  -b SIZE 设置块大小 [默认: ${DEFAULT_BLOCK_SIZE}]"
    echo "  -h      显示帮助信息"
    exit 0
}

# 单位转换函数
format_speed() {
    local speed=$1
    if (( $(echo "$speed > 1024" | bc -l) )); then
        echo "$(echo "scale=2; $speed/1024" | bc -l) GB/s"
    else
        echo "$(echo "scale=2; $speed" | bc -l) MB/s"
    fi
}

# 磁盘测试
disk_test() {
    echo -e "\n${YELLOW}开始磁盘性能测试...${NC}"
    
    # 写测试
    echo "写入测试：使用${BLOCK_SIZE}块大小"
    local write_start=$(date +%s.%N)
    dd if=/dev/zero of="$TEST_FILE" bs=${BLOCK_SIZE} count=$((DISK_SIZE * 1024 / ${BLOCK_SIZE%%M*})) oflag=direct 2>&1 | tail -n 1
    local write_end=$(date +%s.%N)
    
    # 读测试
    echo "读取测试：使用${BLOCK_SIZE}块大小"
    local read_start=$(date +%s.%N)
    dd if="$TEST_FILE" of=/dev/null bs=${BLOCK_SIZE} iflag=direct 2>&1 | tail -n 1
    local read_end=$(date +%s.%N)
    
    # 计算速度
    local write_time=$(echo "$write_end - $write_start" | bc)
    local read_time=$(echo "$read_end - $read_start" | bc)
    local write_speed=$(echo "scale=2; $DISK_SIZE / $write_time" | bc)
    local read_speed=$(echo "scale=2; $DISK_SIZE / $read_time" | bc)

    echo -e "写入速度: ${GREEN}$(format_speed $write_speed)${NC}"
    echo -e "读取速度: ${GREEN}$(format_speed $read_speed)${NC}"
    
    rm -f "$TEST_FILE"
}

# 内存测试
memory_test() {
    echo -e "\n${YELLOW}开始内存性能测试...${NC}"
    
    # 使用dd测试内存速度
    local mem_file="/dev/shm/memtest.tmp"
    local block_count=$((MEM_SIZE * 256))  # 调整为适合的大小
    
    # 写入测试
    local write_speed=$(dd if=/dev/zero of=$mem_file bs=1M count=$MEM_SIZE 2>&1 | tail -n 1 | awk '{print $(NF-1), $NF}')
    
    # 读取测试
    local read_speed=$(dd if=$mem_file of=/dev/null bs=1M 2>&1 | tail -n 1 | awk '{print $(NF-1), $NF}')
    
    echo -e "内存写入速度: ${GREEN}$write_speed${NC}"
    echo -e "内存读取速度: ${GREEN}$read_speed${NC}"
    
    rm -f $mem_file
}

# CPU测试
cpu_test() {
    echo -e "\n${YELLOW}开始CPU性能测试...${NC}"
    
    # 使用bc计算圆周率作为基准测试
    local scale=5000
    echo "计算圆周率（精度位: $scale）"
    
    local start_time=$(date +%s.%N)
    echo "scale=$scale; 4*a(1)" | bc -lq >/dev/null
    local end_time=$(date +%s.%N)
    
    local total_time=$(echo "$end_time - $start_time" | bc)
    echo -e "计算完成时间: ${GREEN}$(printf "%.2f" $total_time) 秒${NC}"
}

# 参数解析
while getopts "dmchs:b:" opt; do
    case $opt in
        d) DISABLE_DISK=true ;;
        m) DISABLE_MEM=true ;;
        c) DISABLE_CPU=true ;;
        s) DISK_SIZE=$OPTARG ;;
        b) BLOCK_SIZE=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# 初始化参数
DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
BLOCK_SIZE=${BLOCK_SIZE:-$DEFAULT_BLOCK_SIZE}
MEM_SIZE=${MEM_SIZE:-$DEFAULT_MEM_SIZE}

# 显示测试配置
echo -e "${GREEN}当前测试配置："
echo "磁盘测试文件大小: ${DISK_SIZE}MB"
echo "块大小: ${BLOCK_SIZE}"
echo "内存测试大小: ${MEM_SIZE}MB"
echo -e "------------------------------${NC}"

# 执行测试
[[ -z $DISABLE_DISK ]] && disk_test
[[ -z $DISABLE_MEM ]] && memory_test
[[ -z $DISABLE_CPU ]] && cpu_test

echo -e "\n${GREEN}所有测试已完成${NC}"