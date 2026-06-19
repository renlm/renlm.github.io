#!/bin/sh
set -e
set -o noglob

# 颜色代码
_RED_='\033[0;31m'   # 红色
_GREEN_='\033[0;32m' # 绿色
_NC_='\033[0m'       # 重置

# [ aarch64 | x86_64 ] 软件包下载
# https://github.com/k3s-io/k3s/releases
K3S_BIN=/usr/local/bin/k3s
K3S_AIRGAP_IMAGES=/var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar
INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-"v1.33.12+k3s1"}
VERSION_K3S=$(echo ${INSTALL_K3S_VERSION} | sed "s/+/-/g")
DOWNLOAD_URL=${DOWNLOAD_URL:-"https://obs.renlm.cn"}
if [ ! -f ${K3S_BIN} ]; then
  mkdir -p /usr/local/bin
  mkdir -p /var/lib/rancher/k3s/agent/images
  # 下载资源
  if uname -m | grep -q aarch64; then
    echo -e "${_GREEN_}[ 下载 ]${_NC_} wget -SqO ${K3S_BIN} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s-arm64"
    wget -SqO ${K3S_BIN} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s-arm64
    echo -e "${_GREEN_}[ 下载 ]${_NC_} wget -SqO ${K3S_AIRGAP_IMAGES} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s-airgap-images-arm64.tar"
    wget -SqO ${K3S_AIRGAP_IMAGES} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s-airgap-images-arm64.tar
  else
    echo -e "${_GREEN_}[ 下载 ]${_NC_} wget -SqO ${K3S_BIN} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s"
    wget -SqO ${K3S_BIN} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s
    echo -e "${_GREEN_}[ 下载 ]${_NC_} wget -SqO ${K3S_AIRGAP_IMAGES} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s-airgap-images-amd64.tar"
    wget -SqO ${K3S_AIRGAP_IMAGES} ${DOWNLOAD_URL}/k3s/${VERSION_K3S}/k3s-airgap-images-amd64.tar
  fi
  # 安装校验
  if [ -f ${K3S_BIN} ]; then
    echo -e "${_GREEN_}[ 安装完成 ]${_NC_} ${K3S_BIN}"
    chmod +x ${K3S_BIN}
    k3s --version
  else
    echo -e "${_RED_}[ 安装失败 ]${_NC_} ${K3S_BIN}"
    exit 1
  fi
else
  echo -e "${_GREEN_}[ 已安装 ]${_NC_} ${K3S_BIN}"
  exit 1
fi

# --- add quotes to command arguments ---
quote() {
  for arg in "$@"; do
    printf '%s\n' "$arg" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"
  done
}

# --- add indentation and trailing slash to quoted args ---
quote_indent() {
  printf ' \\\n'
  for arg in "$@"; do
    printf '\t%s \\\n' "$(quote "$arg")"
  done
}

# --- define needed environment variables ---
setup_env() {
  # --- use command args if passed or create default ---
  case "$1" in
    # --- if we only have flags discover if command should be server or agent ---
    (-*|"")
      if [ -z "${K3S_URL}" ]; then
        CMD_K3S=server
      else
        if [ -z "${K3S_TOKEN}" ] && [ -z "${K3S_TOKEN_FILE}" ]; then
          fatal "Defaulted k3s exec command to 'agent' because K3S_URL is defined, but K3S_TOKEN or K3S_TOKEN_FILE is not defined."
        fi
        CMD_K3S=agent
      fi
    ;;
    # --- command is provided ---
    (*)
      CMD_K3S=$1
      shift
    ;;
  esac

  CMD_K3S_EXEC="${CMD_K3S}$(quote_indent "$@")"
  if [ "${CMD_K3S}" = server ]; then
    SYSTEM_NAME=k3s
  else
    SYSTEM_NAME=k3s-${CMD_K3S}
  fi
}

# 设置开机自启
setup_env "$@"
K3S_SERVICE_FILE="/etc/systemd/system/${SYSTEM_NAME}.service"
if [ ! -f ${K3S_SERVICE_FILE} ]; then
  K3S_ENV_FILE="${K3S_SERVICE_FILE}.env"
  echo -e "[ 开机自启 ] ${K3S_SERVICE_FILE}"
  touch ${K3S_ENV_FILE}
  touch ${K3S_SERVICE_FILE}
  chmod 0600 ${K3S_ENV_FILE}
  chmod 0755 ${K3S_SERVICE_FILE}
  sh -c export | while read x v; do echo $v; done | grep -E '^(K3S|CONTAINERD)_' | tee ${K3S_ENV_FILE} >/dev/null
  sh -c export | while read x v; do echo $v; done | grep -Ei '^(NO|HTTP|HTTPS)_PROXY' | tee -a ${K3S_ENV_FILE} >/dev/null
  cat <<EOF | tee ${K3S_SERVICE_FILE} >/dev/null
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-${K3S_ENV_FILE}
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
fi
