#!/bin/bash
# 用法: ./setup_ssh_key.sh "你的公钥内容"

# KEY="$1"
KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPAEPQxXAeXgL22e/dAJoPLY4RRuM4x1tzu50QxNEH86"

if [ -z "$KEY" ]; then
	echo "用法: $0 \"ssh-rsa AAAAB3Nza...你的公钥\""
	exit 1
fi

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "已备份原配置文件"

# 创建 ~/.ssh 目录
if [ ! -d "$HOME/.ssh" ]; then
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	echo "已创建目录: $HOME/.ssh"
fi

# 创建 authorized_keys 文件并写入密钥
if [ ! -f "$HOME/.ssh/authorized_keys" ]; then
	touch "$HOME/.ssh/authorized_keys"
	chmod 600 "$HOME/.ssh/authorized_keys"
fi

# 检查密钥是否已经存在
if grep -qxF "$KEY" "$HOME/.ssh/authorized_keys"; then
	echo "密钥已存在，未重复添加"
else
	echo "$KEY" >> "$HOME/.ssh/authorized_keys"
	echo "已添加密钥到 $HOME/.ssh/authorized_keys"
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

# 处理 AuthorizedKeysFile 三种情况
if grep -Eq "^[#]?AuthorizedKeysFile\s+" "$SSHD_CONFIG"; then
	sed -i 's|^[#]\?AuthorizedKeysFile\s\+.*|AuthorizedKeysFile .ssh/authorized_keys|' "$SSHD_CONFIG"
	echo "已设置 AuthorizedKeysFile 为 .ssh/authorized_keys"
else
	echo "AuthorizedKeysFile .ssh/authorized_keys" | tee -a "$SSHD_CONFIG" > /dev/null
	echo "已追加 AuthorizedKeysFile .ssh/authorized_keys"
fi

# 处理 PubkeyAuthentication 三种情况
if grep -Eq "^[#]?PubkeyAuthentication\s+no" "$SSHD_CONFIG"; then
	sed -i 's|^[#]\?PubkeyAuthentication\s\+no|PubkeyAuthentication yes|' "$SSHD_CONFIG"
	echo "已将 PubkeyAuthentication 修改为 yes"
elif grep -Eq "^[#]?PubkeyAuthentication\s+yes" "$SSHD_CONFIG"; then
	sed -i 's|^[#]\?PubkeyAuthentication\s\+yes|PubkeyAuthentication yes|' "$SSHD_CONFIG"
	echo "已取消注释 PubkeyAuthentication yes"
else
	echo "PubkeyAuthentication yes" | tee -a "$SSHD_CONFIG" > /dev/null
	echo "已追加 PubkeyAuthentication yes"
fi

# 检查 sshd 配置语法
if command -v sshd >/dev/null 2>&1; then
	if sshd -t; then
		echo "sshd 配置检查通过"
		# 重启 ssh 服务
		if command -v systemctl >/dev/null 2>&1; then
			systemctl restart sshd
		else
			service ssh restart
		fi
		echo "SSH 公钥配置完成"
	else
		echo "错误: sshd 配置检查失败，请手动修复 /etc/ssh/sshd_config"
		exit 1
	fi
else
	echo "警告: 找不到 sshd 命令，无法检查配置"
fi
