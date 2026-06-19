#!/bin/sh
set -e
set -o noglob

# 颜色代码
export _RED_='\033[0;31m'   # 红色
export _GREEN_='\033[0;32m' # 绿色
export _NC_='\033[0m'       # 重置

# [ aarch64 | x86_64 ] 软件包下载
# https://github.com/k3s-io/k3s/releases
export K3S_BIN=/usr/local/bin/k3s
export K3S_AIRGAP_IMAGES=/var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar
export INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-"v1.33.12+k3s1"}
if [ ! -f ${K3S_BIN} ]; then
  mkdir -p /usr/local/bin
  mkdir -p /var/lib/rancher/k3s/agent/images
  # 下载资源
  if uname -m | grep -q aarch64; then
    wget -O ${K3S_BIN} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s-arm64
    wget -O ${K3S_AIRGAP_IMAGES} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s-airgap-images-arm64.tar
  else
    wget -O ${K3S_BIN} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s
    wget -O ${K3S_AIRGAP_IMAGES} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s-airgap-images-amd64.tar
  fi
  # 安装校验
  if [ -f ${K3S_BIN} ]; then
    echo -e "${_GREEN_}[ 安装完成 ] ${K3S_BIN} ${_NC_}"
    chmod +x ${K3S_BIN}
    k3s --version
  else
    echo -e "${_RED_}[ 安装失败 ] ${K3S_BIN} ${_NC_}"
    exit 1
  fi
else
  echo -e "${_GREEN_}[ 已安装 ] ${K3S_BIN} ${_NC_}"
  exit 1
fi

# 设置开机自启
export SYSTEMD_TYPE=${SYSTEMD_TYPE:-"notify"}
export K3S_SERVICE=/etc/systemd/system/k3s.service
cat <<EOF | tee ${K3S_SERVICE}
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=${SYSTEMD_TYPE}
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-${FILE_K3S_ENV}
KillMode=process
Delegate=yes
User=root
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=${K3S_BIN} \\
    ${CMD_K3S_EXEC}

EOF
