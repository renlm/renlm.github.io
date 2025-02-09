#!/bin/sh

set -e
set -o noglob

# 动态变量（参数传递）
DATA_ROOT=${@:-'/home/docker'}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS:-'https://docker.1ms.run'}

# 获取操作系统
system=`lsb_release -i | cut -f 2`
echo "The system is $system."
 
# 根据操作系统执行不同的脚本
if [ "$system" = "Ubuntu" ]; then
	curl -sfL https://github-io.renlm.cn/script/docker/install/ubuntu.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS sh -s - $DATA_ROOT
else
	echo "Does not support automatic installation of Docker."
fi