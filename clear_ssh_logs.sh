#!/bin/bash
# 清除 SSH 登录相关日志
# 适用于常见 Linux 发行版 (Debian/Ubuntu/CentOS/RHEL/Fedora/Arch 等)

LOG_FILES=(
    "/var/log/auth.log"
    "/var/log/secure"
    "/var/log/messages"
    "/var/log/lastlog"
)

echo "[*] 清理常见 SSH 日志文件..."
for file in "${LOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "" > "$file"
        echo "已清空: $file"
    fi
done

echo "[*] 清理 wtmp/utmp/btmp..."
> /var/log/wtmp 2>/dev/null
> /var/log/btmp 2>/dev/null
> /var/log/utmp 2>/dev/null

echo "[*] 尝试清理 systemd journal 中 sshd 记录..."
if command -v journalctl >/dev/null 2>&1; then
    journalctl --rotate
    journalctl --vacuum-time=1s -u sshd
    echo "已清理 systemd journal 中的旧日志"
fi

echo "[*] SSH 登录日志清理完成！"
