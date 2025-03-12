#!/bin/bash
set -e
set +o noglob

# 脚本参数
DATA_ROOT=${@}
OS_MIRRORS=${OS_MIRRORS}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS}

# 镜像源
# http://mirrors.aliyun.com/repo/
# https://mirrors.huaweicloud.com/repository/conf/
# https://mirrors.cloud.tencent.com/repo/
# https://developer.aliyun.com/mirror/docker-ce
OS_MAIN_VERSION=`cat /etc/os-release | grep ^VERSION_ID= | cut -d = -f 2 | tr -d '"' | cut -d . -f 1`
# 安装脚本
if [ "$OS_MIRRORS" = "tencent" ]; then
  rm -fr /etc/yum.repos.d/* \
    && wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.cloud.tencent.com/repo/centos7_base.repo \
    && wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.tencent.com/docker-ce/linux/centos/docker-ce.repo \
    && sed -i 's/\$releasever/7/g' /etc/yum.repos.d/CentOS-Base.repo \
    && sed -i 's|download.docker.com|mirrors.cloud.tencent.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo \
    && sed -i 's/\$releasever/7/g' /etc/yum.repos.d/docker-ce.repo \
    && rm -rf /var/cache/yum/* \
    && yum makecache
elif [ "$OS_MIRRORS" = "aliyun" ]; then
  rm -fr /etc/yum.repos.d/* \
    && wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-${OS_MAIN_VERSION}.repo \
    && wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo \
    && sed -i 's/\$releasever/'${OS_MAIN_VERSION}'/g' /etc/yum.repos.d/CentOS-Base.repo \
    && sed -i 's|download.docker.com|mirrors.huaweicloud.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo \
    && sed -i 's/\$releasever/'${OS_MAIN_VERSION}'/g' /etc/yum.repos.d/docker-ce.repo \
    && rm -rf /var/cache/yum/* \
    && yum makecache
elif [ "$OS_MIRRORS" = "huaweicloud" ]; then
  rm -fr /etc/yum.repos.d/* \
    && wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.huaweicloud.com/repository/conf/CentOS-${OS_MAIN_VERSION}-anon.repo \
    && wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.huaweicloud.com/docker-ce/linux/centos/docker-ce.repo \
    && sed -i 's/\$releasever/'${OS_MAIN_VERSION}'/g' /etc/yum.repos.d/CentOS-Base.repo \
    && sed -i 's|download.docker.com|mirrors.huaweicloud.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo \
    && sed -i 's/\$releasever/'${OS_MAIN_VERSION}'/g' /etc/yum.repos.d/docker-ce.repo \
    && rm -rf /var/cache/yum/* \
    && yum makecache
fi
  
# 安装
# https://docs.docker.com/engine/install/rhel/
yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
