#!/bin/sh
set -e
set -o noglob

########################################################################
INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-"v1.33.12+k3s1"}
DOWNLOAD_K3S_VERSION=$(echo ${INSTALL_K3S_VERSION} | sed "s/+/-/g")
DOWNLOADER_URL=${DOWNLOADER_URL:-"https://obs.renlm.cn"}
###### master 主节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - server --disable=traefik --tls-san k3s.renlm.cn --cluster-init
###### master 从节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - server --disable=traefik --server https://k3s.renlm.cn:6443
###### agent 节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - agent --server https://k3s.renlm.cn:6443
########################################################################

# 颜色代码
_RED_='\033[0;31m'    # 红色
_GREEN_='\033[0;32m'  # 绿色
_YELLOW_='\033[0;33m' # 黄色
_NC_='\033[0m'        # 重置

# --- download from url ---
download() {
  [ $# -eq 2 ] || fatal 'download needs exactly 2 arguments'

  # Disable exit-on-error so we can do custom error messages on failure
  set +e

  # Default to a failure status
  status=1

  case $DOWNLOADER in
    curl)
      echo -e "[ ${_GREEN_}下载${_NC_} ] curl -o $1 -sfL $2"
      curl -o $1 -sfL $2
      status=$?
    ;;
    wget)
      echo -e "[ ${_GREEN_}下载${_NC_} ] wget -qO $1 $2"
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
create_service() {
  setup_env "$@"
  K3S_SERVICE_FILE="/etc/systemd/system/${SYSTEM_NAME}.service"
  K3S_ENV_FILE="${K3S_SERVICE_FILE}.env"
  echo -e "[ ${_GREEN_}开机自启${_NC_} ] ${K3S_SERVICE_FILE}"
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
ExecStart=${INSTALL_K3S_BIN} \\
    ${CMD_K3S_EXEC}

EOF
{
  systemctl daemon-reload
  systemctl enable ${SYSTEM_NAME}
  systemctl restart ${SYSTEM_NAME}
  echo -e "[ ${_GREEN_}启动成功${_NC_} ] ${SYSTEM_NAME}"
}
if [ "${CMD_K3S}" = server ]; then
  sed -i '$a export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' /etc/profile
  sed -i '$a alias kubectl="k3s kubectl"' /etc/profile
  sed -i '$a alias ctr="k3s ctr"' /etc/profile
  sed -i '$a alias crictl="k3s crictl"' /etc/profile
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  alias kubectl="k3s kubectl"
  alias ctr="k3s ctr"
  alias crictl="k3s crictl"
  kubectl get nodes
  ctr -n k8s.io c ls
  kubectl version --output=json
fi
}

# [ aarch64 | x86_64 ] 软件包下载
# https://github.com/k3s-io/k3s/releases
INSTALL_K3S_BIN=/usr/local/bin/k3s
INSTALL_K3S_IMAGES=/var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar
DOWNLOADER=curl
if [ ! -f ${INSTALL_K3S_BIN} ]; then
  mkdir -p /usr/local/bin
  mkdir -p /var/lib/rancher/k3s/agent/images
  # 下载资源
  if uname -m | grep -q aarch64; then
    download ${INSTALL_K3S_BIN} ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-arm64
    download ${INSTALL_K3S_IMAGES} ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-arm64.tar
  else
    download ${INSTALL_K3S_BIN} ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s
    download ${INSTALL_K3S_IMAGES} ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-amd64.tar
  fi
  # 安装校验
  if [ -f ${INSTALL_K3S_BIN} ]; then
    echo -e "[ ${_GREEN_}安装${_NC_} ] ${INSTALL_K3S_BIN}"
    chmod +x ${INSTALL_K3S_BIN}
    create_service
  else
    echo -e "[ ${_RED_}安装失败${_NC_} ] ${INSTALL_K3S_BIN}"
    exit 1
  fi
else
  echo -e "[ ${_YELLOW_}已安装${_NC_} ] ${INSTALL_K3S_BIN}"
  exit 1
fi
