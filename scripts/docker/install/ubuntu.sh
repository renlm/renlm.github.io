#!/bin/bash
set -e
set -o noglob

# 脚本参数
DATA_ROOT=${@}
OS_MIRRORS=${OS_MIRRORS}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS}

# 软件源
if [ "$OS_MIRRORS" = "tencent" ]; then
  if [ -s /etc/apt/sources.list.d/debian.sources ]; then
    sed -i 's/deb.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list.d/debian.sources
  elif [ -s /etc/apt/sources.list ]; then
    sed -i 's/deb.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list
    sed -i 's|security.debian.org/debian-security|mirrors.cloud.tencent.com/debian-security|g' /etc/apt/sources.list
  fi
elif [ "$OS_MIRRORS" = "aliyun" ]; then
  if [ -s /etc/apt/sources.list.d/debian.sources ]; then
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources
  elif [ -s /etc/apt/sources.list ]; then
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
    sed -i 's|security.debian.org/debian-security|mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list
  fi
elif [ "$OS_MIRRORS" = "huaweicloud" ]; then
  if [ -s /etc/apt/sources.list.d/debian.sources ]; then
    sed -i 's/deb.debian.org/mirrors.huaweicloud.com/g' /etc/apt/sources.list.d/debian.sources
  elif [ -s /etc/apt/sources.list ]; then
    sed -i 's/deb.debian.org/mirrors.huaweicloud.com/g' /etc/apt/sources.list
    sed -i 's|security.debian.org/debian-security|mirrors.huaweicloud.com/debian-security|g' /etc/apt/sources.list
  fi
fi

# 安装
apt-get update
apt-get install -y docker.io docker-buildx docker-compose-v2
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

# 配置
cat <<EOF | tee /etc/docker/daemon.json > /dev/null
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
