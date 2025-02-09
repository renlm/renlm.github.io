#!/bin/bash

set -e
set -o noglob

# 参数
DATA_ROOT=${@:-'/home/docker'}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS:-'https://docker.1ms.run'}

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