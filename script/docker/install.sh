#!/bin/bash

set -e
set -o noglob

# 参数
DATA_ROOT=${@:-'/home/docker'}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS:-'https://docker.1ms.run'}

# 操作系统
system=`lsb_release -i | cut -f 2`
echo "The system is $system."
 
# 安装脚本
if [ "$system" = "Ubuntu" ]; then
	curl -sfL https://github-io.renlm.cn/script/docker/install/ubuntu.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS bash -s $DATA_ROOT
else
	echo "Does not support automatic installation of Docker."
fi