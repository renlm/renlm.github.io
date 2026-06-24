#!/bin/sh
set -e
set -o noglob
########################################################################
# https://distribution.github.io/distribution/about/deploying
DOCKER_INSTALL_SH="https://renlm.github.io/sh/docker-install.sh"
REGISTRY_INSTALL_SH="https://renlm.github.io/sh/docker-registry.sh"
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
REGISTRY_HOME=${DOCKER_ROOT}/deploy/registry
REGISTRY_USER=${REGISTRY_USER:-"usr_registry"}
REGISTRY_VERSION=${REGISTRY_VERSION:-"3.1.1"}
REGISTRY_PORT=${REGISTRY_PORT:-"5000"}
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
  
  # 读取本地文件
  if $DOWNLOAD_SKIP; then
    if [ ! -f $1 ]; then
      fatal "请上传文件：$1"
    else
      info "读取本地文件：$1"
    fi
  # 下载软件包
  else
    # Disable exit-on-error so we can do custom error messages on failure
    set +e

    # Default to a failure status
    status=1
    case $DOWNLOADER in
      curl)
        printf "[ ${_GREEN_}下载${_NC_} ] curl -o $1 -sfL $2\n"
        mkdir -p ${1%/*}
        curl -o $1 -sfL $2
        status=$?
      ;;
      wget)
        printf "[ ${_GREEN_}下载${_NC_} ] wget -qO $1 $2\n"
        mkdir -p ${1%/*}
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
  fi
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
# 下载并安装
if $DOWNLOAD_SKIP; then
  DOWNLOADS_ROOT=${DOWNLOADS_BASENAME}
fi
if [ "${MODE}" = PKG ]; then
  DOWNLOADS_FILE_SH=install.sh
  TOOLS_IMAGES_TAR=docker/images/registry-${REGISTRY_VERSION}-${ARCH_ALIAS}.tar.gz
  download ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR} ${DOWNLOADER_URL}/${TOOLS_IMAGES_TAR}
  download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_SH} ${REGISTRY_INSTALL_SH}
  curl -sfL $DOCKER_INSTALL_SH | NOT_INNER_SH=false MODE=$MODE ARCH=$ARCH sh
  mv docker-install.${ARCH}.tar.gz $DOWNLOADS_ROOT
  info "生成离线包: tar -czf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz -C ${DOWNLOADS_ROOT%/*} ${DOWNLOADS_BASENAME}"
  tar -czf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz -C ${DOWNLOADS_ROOT%/*} ${DOWNLOADS_BASENAME}
  info "离线安装 - 第1步：上传离线安装包 ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz"
  info "离线安装 - 第2步：解压离线安装包 tar -zxvf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz"
  info "\$ cat ${DOWNLOADS_BASENAME}/install.sh | DOWNLOAD_SKIP=true DOCKER_ROOT=/data DOCKER_IPTABLES=true sh"
# 安装服务
else
  # 安装Docker
  if which docker > /dev/null 2>&1; then
    printf "[ ${_YELLOW_}已安装${_NC_} ] $(which docker)\n"
  else
    # 离线模式
    if $DOWNLOAD_SKIP; then
      cat docker-install/install.sh | NOT_INNER_SH=false DOWNLOAD_SKIP=true DOCKER_ROOT=$DOCKER_ROOT DOCKER_IPTABLES=$DOCKER_IPTABLES sh
    # 在线模式
    else
      curl -sfL $DOCKER_INSTALL_SH | NOT_INNER_SH=false DOCKER_ROOT=$DOCKER_ROOT DOCKER_IPTABLES=$DOCKER_IPTABLES sh
    fi
  fi

  # 启动registry
  TOOLS_IMAGES_TAR=docker/images/registry-${REGISTRY_VERSION}-${ARCH_ALIAS}
  download ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR}.tar.gz ${DOWNLOADER_URL}/${TOOLS_IMAGES_TAR}.tar.gz
  tar -zxf ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR}.tar.gz -C ${DOWNLOADS_ROOT}/docker/images
  while IFS= read -r line; do
    TXT_LINE=$((TXT_LINE+1))
    if [ $TXT_LINE -gt 1 ]; then
      line_val=$(echo "$line" | cut -d "=" -f2)
      line_tar=$(echo "$line_val" | cut -d "@" -f2)
      docker load -i ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR}/$line_tar
    fi
  done < ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR}/registry-${REGISTRY_VERSION}-${ARCH_ALIAS}.txt
  if [ -f ${REGISTRY_HOME}/docker-compose.yml ]; then
    warn "服务已存在：${REGISTRY_HOME}/docker-compose.yml"
  else
    mkdir -p ${REGISTRY_HOME}
    DEFAULT_HTPASSWD=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
    docker run --entrypoint htpasswd httpd:2 -b -nBC12 ${REGISTRY_USER} ${DEFAULT_HTPASSWD} > ${REGISTRY_HOME}/auth_htpasswd
    warn "$ cat ${REGISTRY_HOME}/.auth_htpasswd"
    warn "$ docker login --username=${REGISTRY_USER} http://localhost:${REGISTRY_PORT}"
    cat <<EOF | tee ${REGISTRY_HOME}/.auth_htpasswd >/dev/null
[default]
username=${REGISTRY_USER}
password=${DEFAULT_HTPASSWD}
EOF
    cat <<EOF | tee ${REGISTRY_HOME}/docker-compose.yml >/dev/null
services:
  registry:
    image: registry:${REGISTRY_VERSION}
    container_name: registry
    hostname: registry
    restart: always
    ports:
    - ${REGISTRY_PORT}:${REGISTRY_PORT}
    healthcheck:
      test:
      - CMD
      - curl
      - -f
      - http://localhost:${REGISTRY_PORT}
      interval: 5s
      timeout: 5s
      retries: 36
    environment:
      OTEL_TRACES_EXPORTER: none
      REGISTRY_HTTP_ADDR: 0.0.0.0:${REGISTRY_PORT}
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: basic-realm
    volumes:
    - ${REGISTRY_HOME}/auth_htpasswd:/auth/htpasswd
    - ${REGISTRY_HOME}/var_lib_registry:/var/lib/registry
EOF
{
  docker-compose -f ${REGISTRY_HOME}/docker-compose.yml up -d
}
fi
fi
