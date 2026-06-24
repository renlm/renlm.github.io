#!/bin/sh
set -e
set -o noglob
########################################################################
# https://distribution.github.io/distribution/about/deploying
### 一键安装
# $ curl -sfL https://renlm.github.io/sh/docker-registry.sh | DOCKER_ROOT=/data DOCKER_IPTABLES=true sh
########################################################################
DOCKER_INSTALL_SH="https://renlm.github.io/sh/docker-install.sh"
REGISTRY_INSTALL_SH="https://renlm.github.io/sh/docker-registry.sh"
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
DOCKER_IPTABLES=${DOCKER_IPTABLES:-true}
DOWNLOADER_URL=${DOWNLOADER_URL:-"https://oss.renlm.cn"}
DOWNLOAD_SKIP=${DOWNLOAD_SKIP:-false}

# 颜色代码
_RED_='\033[0;31m'    # 红色
_GREEN_='\033[0;32m'  # 绿色
_YELLOW_='\033[0;33m' # 黄色
_NC_='\033[0m'        # 重置

# --- helper functions for logs ---
info()
{
  printf "[ ${_GREEN_}INFO${_NC_} ] $@\n"
}
warn()
{
  printf "[ ${_YELLOW_}WARN${_NC_} ] $@\n" >&2
}
fatal()
{
  printf "[ ${_RED_}ERROR${_NC_} ] $@\n" >&2
  exit 1
}

# 安装Docker
if which docker > /dev/null 2>&1; then
  printf "[ ${_YELLOW_}已安装${_NC_} ] $(which docker)\n"
else
  # 离线模式
  if $DOWNLOAD_SKIP; then
  
  # 在线模式
  else
    curl -sfL $DOCKER_INSTALL_SH | DOCKER_ROOT=$DOCKER_ROOT DOCKER_IPTABLES=$DOCKER_IPTABLES sh
  fi
fi
