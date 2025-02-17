#!/bin/bash
set -e
set -o noglob

# 脚本参数
DATA_ROOT=${@}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS}

# 镜像源
# https://developer.aliyun.com/mirror/docker-ce
OS_MAIN_VERSION=`cat /etc/os-release | grep ^VERSION_ID= | cut -d = -f 2 | tr -d '"' | cut -d . -f 1`
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-${OS_MAIN_VERSION}.repo \
  && wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo \
  && sed -i 's/\$releasever/'${OS_MAIN_VERSION}'/g' /etc/yum.repos.d/epel.repo \
  && sed -i 's/\$releasever/'${OS_MAIN_VERSION}'/g' /etc/yum.repos.d/docker-ce.repo \
  && yum clean all \
  && yum makecache
  
# 安装
# https://docs.docker.com/engine/install/rhel/
yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

# 配置
cat <<EOF | tee /etc/docker/daemon.json
{
  "data-root": "$DATA_ROOT",
  "features": { "buildkit" : true },
  "exec-opts": [ "native.cgroupdriver=systemd" ],
  "registry-mirrors": [ "$REGISTRY_MIRRORS" ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" }
}
EOF

# 重启
systemctl daemon-reload
systemctl restart docker
