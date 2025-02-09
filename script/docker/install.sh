#!/bin/sh

set -e
set -o noglob

system=`lsb_release -a 2> /dev/null | grep "Distributor ID:" | cut -d ":" -f2`
echo "The system is $system."
 
if [ "$system" == "Ubuntu" ]; then
	curl -sfL https://github-io.renlm.cn/script/docker/install/ubuntu.sh | sh -s - 
else
	echo "Does not support automatic installation of Docker."
fi