#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要root权限。请使用sudo运行或切换为root用户。"
    exit 1
fi

# 检查是否已安装ntpdate
if ! command -v ntpdate &>/dev/null; then
    echo "未找到ntpdate，开始安装..."
    
    # 确定包管理器并更新安装
    if command -v apt-get &>/dev/null; then
        echo "检测到APT包管理器，正在更新软件源..."
        apt-get update
        echo "安装ntpdate..."
        apt-get install -y ntpdate
    elif command -v yum &>/dev/null; then
        echo "检测到YUM包管理器，正在更新系统..."
        yum update -y
        echo "安装ntpdate..."
        yum install -y ntpdate
    else
        echo "错误：未找到支持的包管理器（APT或YUM）。"
        exit 1
    fi

    # 再次检查安装结果
    if ! command -v ntpdate &>/dev/null; then
        echo "安装ntpdate失败，请检查网络或手动安装。"
        exit 1
    fi
fi

# 执行时间同步
echo "正在同步时间..."
if ntpdate pool.ntp.org; then
    echo "时间同步成功！"
else
    echo "时间同步失败，请检查网络或NTP服务状态。"
    exit 1
fi
# 要添加的定时任务（示例：每天凌晨 1 点执行 /data/clean_log.sh）
cron_job="0 1 * * * ntpdate pool.ntp.org >/dev/null 2>&1"

# 检查任务是否已存在
crontab -l 2>/dev/null | grep -F "$cron_job" >/dev/null
if [ $? -eq 0 ]; then
    echo "定时任务已存在，无需重复添加。"
else
    # 追加任务
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    echo "定时任务已添加：$cron_job"
fi
exit 0
