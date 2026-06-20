#!/bin/sh
set -e
set -o noglob

########################################################################
# https://get.k3s.io
# https://docs.k3s.io/zh/installation/configuration
# https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-14-2/
# https://helm.sh/docs/topics/version_skew/
# https://github.com/k3s-io/k3s/releases
# https://github.com/helm/helm/releases/
# [ 版本匹配 ] k3s: v1.34.8+k3s1, helm: v4.0.5, rancher: v2.14.2
INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-"v1.34.8+k3s1"}
INSTALL_HELM_VERSION=${INSTALL_HELM_VERSION:-"v4.0.5"}
DOWNLOAD_K3S_VERSION=$(echo ${INSTALL_K3S_VERSION} | sed "s/+/-/g")
DOWNLOADER_URL=${DOWNLOADER_URL:-"https://obs.renlm.cn"}
###### master 主节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - server --disable=traefik --tls-san k3s.renlm.cn --cluster-init
###### master 从节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - server --disable=traefik --server https://k3s.renlm.cn:6443
###### agent 节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - agent --server https://k3s.renlm.cn:6443
###### 重载命令行别名
# $ source ~/.bashrc
# $ helm version
# $ kubectl get nodes
# $ kubectl version --output=json
# $ ctr -n k8s.io c ls
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
      mkdir -p ${1%/*}
      curl -o $1 -sfL $2
      status=$?
    ;;
    wget)
      echo -e "[ ${_GREEN_}下载${_NC_} ] wget -qO $1 $2"
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
  echo -e "[ ${_GREEN_}启动服务${_NC_} ] ${SYSTEM_NAME}"
}
{
  ln -sf /usr/local/helm-${INSTALL_HELM_VERSION}/helm /usr/local/bin/helm
  sed -i '$a export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc
  sed -i '$a alias kubectl="k3s kubectl"' ~/.bashrc
  sed -i '$a alias ctr="k3s ctr"' ~/.bashrc
  sed -i '$a alias crictl="k3s crictl"' ~/.bashrc
  echo -e "[ ${_YELLOW_}KUBECONFIG${_NC_} ] /etc/rancher/k3s/k3s.yaml"
  echo -e "${_YELLOW_}[ 手动执行 ]${_NC_} source ~/.bashrc"
}
if [ "${CMD_K3S}" = server ]; then
  echo -e "[ ${_GREEN_}SLEEPING${_NC_} ] 5s"
  sleep 5s
  helm version
  k3s kubectl get nodes
  k3s kubectl version --output=json
fi
}

# [ aarch64 | x86_64 ] 软件包下载
INSTALL_HELM_BIN=/usr/local/bin/helm
INSTALL_K3S_BIN=/usr/local/bin/k3s
INSTALL_K3S_IMAGES=/var/lib/rancher/k3s/agent/images/
DOWNLOADS_ROOT=/opt/k3s-install
DOWNLOADER=curl
# helm
if [ ! -f ${INSTALL_HELM_BIN} ]; then
  # 下载软件包
  if uname -m | grep -q aarch64; then
    download ${DOWNLOADS_ROOT}/helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-arm64.tar.gz ${DOWNLOADER_URL}/helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-arm64.tar.gz
    tar -zxf ${DOWNLOADS_ROOT}/helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-arm64.tar.gz -C /usr/local --transform="s/linux-arm64/helm-${INSTALL_HELM_VERSION}/g"
  else
    download ${DOWNLOADS_ROOT}/helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-amd64.tar.gz ${DOWNLOADER_URL}/helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-amd64.tar.gz
    tar -zxf ${DOWNLOADS_ROOT}/helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-amd64.tar.gz -C /usr/local --transform="s/linux-amd64/helm-${INSTALL_HELM_VERSION}/g"
  fi
fi
# k3s
if [ ! -f ${INSTALL_K3S_BIN} ]; then
  # 下载软件包
  mkdir -p ${INSTALL_K3S_IMAGES}
  if uname -m | grep -q aarch64; then
    download ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-arm64 ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-arm64
    download ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-arm64.tar ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-arm64.tar
    cp ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-arm64 ${INSTALL_K3S_BIN}
    cp ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-arm64.tar ${INSTALL_K3S_IMAGES}
  else
    download ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s
    download ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-amd64.tar ${DOWNLOADER_URL}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-amd64.tar
  	cp ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s ${INSTALL_K3S_BIN}
    cp ${DOWNLOADS_ROOT}/k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-amd64.tar ${INSTALL_K3S_IMAGES}
  fi
  # 安装校验
  if [ -f ${INSTALL_K3S_BIN} ]; then
    echo -e "[ ${_GREEN_}安装${_NC_} ] ${INSTALL_K3S_BIN}"
    chmod +x ${INSTALL_K3S_BIN}
    setup_env "$@"
    create_service
  else
    echo -e "[ ${_RED_}安装失败${_NC_} ] ${INSTALL_K3S_BIN}"
    exit 1
  fi
else
  echo -e "[ ${_YELLOW_}已安装${_NC_} ] ${INSTALL_K3S_BIN}"
  exit 1
fi
