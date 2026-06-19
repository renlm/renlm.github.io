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
    wget -O ${K3S_BIN} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s
    wget -O ${K3S_AIRGAP_IMAGES} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s-airgap-images-arm64.tar
  else
    wget -O ${K3S_BIN} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s
    wget -O ${K3S_AIRGAP_IMAGES} https://obs.renlm.cn/k3s/${INSTALL_K3S_VERSION}/k3s-airgap-images-amd64.tar
  fi
  # 校验资源
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
