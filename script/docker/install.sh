#!/bin/sh

set -e
set -o noglob

REGISTRY_MIRRORS=${REGISTRY_MIRRORS:-'https://docker-io.renlm.cn'}

system=`lsb_release -a 2> /dev/null | grep "Distributor ID:" | cut -d ":" -f2`
echo "The system is $system."
 
if [ "$system" == "Ubuntu" ]; then
	curl -sfL https://github-io.renlm.cn/script/docker/install/ubuntu.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS sh -s - 
else
	echo "Does not support automatic installation of Docker."
fi