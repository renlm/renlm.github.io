#!/bin/sh
set -e
set -o noglob
########################################################################
# https://distribution.github.io/distribution/about/deploying
DOCKER_INSTALL_SH="https://renlm.github.io/sh/docker-install.sh"
REGISTRY_INSTALL_SH="https://renlm.github.io/sh/docker-registry.sh"
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
DOCKER_IPTABLES=${DOCKER_IPTABLES:-true}
DOWNLOADER_URL=${DOWNLOADER_URL:-"https://oss.renlm.cn"}
DOWNLOAD_SKIP=${DOWNLOAD_SKIP:-false}
# 执行模式
# INSTALL: 安装
# PKG: 生成离线安装包
MODE=${MODE:-"INSTALL"}
# CPU 指令集架构
# auto: 根据服务器自动识别
# [ ARCH_ALIAS=amd64 ] x86_64: Intel/AMD 阵营的 64 位
# [ ARCH_ALIAS=arm64 ] aarch64: ARM 阵营的 64 位
ARCH=${ARCH:-"auto"}
### 一键安装
# $ curl -sfL https://renlm.github.io/sh/docker-registry.sh | DOCKER_ROOT=/data DOCKER_IPTABLES=true sh
########################################################################

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

# --- download from url ---
download() {
  [ $# -eq 2 ] || fatal 'download needs exactly 2 arguments'

  # Disable exit-on-error so we can do custom error messages on failure
  set +e

  # Default to a failure status
  status=1

  case $DOWNLOADER in
    curl)
      printf "[ ${_GREEN_}下载${_NC_} ] curl -o $1 -sfL $2\n"
      curl -o $1 -sfL $2
      status=$?
    ;;
    wget)
      printf "[ ${_GREEN_}下载${_NC_} ] wget -qO $1 $2\n"
      wget -qO $1 $2
      status=$?
    ;;
    *)
      # Enable exit-on-error for fatal to execute
      set -e
      fatal "Incorrect executable '$DOWNLOADER'"
    ;;
  esac

  # Re-enable exit-on-error
  set -e

  # Abort if download command failed
  [ $status -eq 0 ] || fatal 'Download failed'
}

# 参数校验
if [ "$MODE" = INSTALL ] || [ "$MODE" = PKG ]; then
  if [ "$MODE" = PKG ]; then
    DOWNLOAD_SKIP=false
  fi
  {
	info "MODE: $MODE"
    info "DOWNLOAD_SKIP: $DOWNLOAD_SKIP"
  }
else
  fatal "Unknown MODE: $MODE, INSTALL or PKG"
fi
if [ "$ARCH" = auto ] || [ "$ARCH" = x86_64 ] || [ "$ARCH" = aarch64 ]; then
  if uname -m | grep -q aarch64; then
    ARCH=aarch64
    ARCH_ALIAS=arm64
  else
    ARCH=x86_64
    ARCH_ALIAS=amd64
  fi
  {
	info "ARCH: $ARCH"
	info "ARCH_ALIAS: $ARCH_ALIAS"
  }
else
  fatal "Unknown ARCH: $ARCH, auto or x86_64 or aarch64"
fi

# 生成离线包
DOWNLOADS_ROOT=/opt/docker-registry
DOWNLOADS_BASENAME=$(basename $DOWNLOADS_ROOT)
DOWNLOADER=curl
if [ "${MODE}" = PKG ]; then
  DOWNLOADS_FILE_SH=install.sh
  TOOLS_IMAGES_TAR=docker/images/tools-${ARCH_ALIAS}.tar.gz
  download ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR} ${DOWNLOADER_URL}/${TOOLS_IMAGES_TAR}
  download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_SH} ${REGISTRY_INSTALL_SH}
  curl -sfL $DOCKER_INSTALL_SH | MODE=$MODE ARCH=$ARCH sh
  mv docker-install.${ARCH}.tar.gz $DOWNLOADS_ROOT
# 安装服务
else
  # 安装Docker
  if which docker > /dev/null 2>&1; then
    printf "[ ${_YELLOW_}已安装${_NC_} ] $(which docker)\n"
  else
    # 离线模式
    if $DOWNLOAD_SKIP; then
      cat docker-install/install.sh | DOWNLOAD_SKIP=true DOCKER_ROOT=$DOCKER_ROOT DOCKER_IPTABLES=$DOCKER_IPTABLES sh
    # 在线模式
    else
      curl -sfL $DOCKER_INSTALL_SH | DOCKER_ROOT=$DOCKER_ROOT DOCKER_IPTABLES=$DOCKER_IPTABLES sh
    fi
  fi

  # 启动registry
  
fi
