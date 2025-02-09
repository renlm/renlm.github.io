#!/bin/bash

set -e
set -o noglob

# 脚本参数
DATA_ROOT=${@:-'/home/docker'}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS:-'https://docker.1ms.run'}

# 内核参数
if ! grep -q '^fs.inotify.max_user_instances' /etc/sysctl.conf; then
	sed -i '$a fs.inotify.max_user_instances = 8192' /etc/sysctl.conf
fi
if [ -s /etc/sysctl.conf ]; then
	sysctl -p
fi

# 操作系统
OS_ID=`cat /etc/os-release | grep ^ID= | cut -d = -f 2 | tr -d '"'`
OS_VERSION=`cat /etc/os-release | grep ^VERSION_ID= | cut -d = -f 2 | tr -d '"'`
echo "The system is $OS_ID $OS_VERSION."
 
# 安装脚本
if [ "$OS_ID" = "ubuntu" ]; then
	curl -sfL https://github-io.renlm.cn/script/docker/install/ubuntu.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS bash -s $DATA_ROOT
elif [ "$OS_ID" = "rhel" ]; then
	curl -sfL https://github-io.renlm.cn/script/docker/install/rhel.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS bash -s $DATA_ROOT
else
	echo "Does not support automatic installation of Docker."
fi

# 修改构建日志限制
if [ -s /etc/systemd/system/multi-user.target.wants/docker.service ]; then
	if ! grep -q '^Environment="BUILDKIT_STEP_LOG_MAX_SIZE=' /etc/systemd/system/multi-user.target.wants/docker.service; then
		sed -i '/\[Service\]/a\Environment="BUILDKIT_STEP_LOG_MAX_SPEED=10240000"' /etc/systemd/system/multi-user.target.wants/docker.service
		sed -i '/\[Service\]/a\Environment="BUILDKIT_STEP_LOG_MAX_SIZE=1073741824"' /etc/systemd/system/multi-user.target.wants/docker.service
		systemctl daemon-reload
		systemctl restart docker
	fi
fi