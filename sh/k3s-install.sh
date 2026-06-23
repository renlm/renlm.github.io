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
INSTALL_SH=${INSTALL_SH:-"https://renlm.github.io/sh/k3s-install.sh"}
INSTALL_K3S_VERSION=${INSTALL_K3S_VERSION:-"v1.34.8+k3s1"}
INSTALL_HELM_VERSION=${INSTALL_HELM_VERSION:-"v4.0.5"}
DOWNLOAD_K3S_VERSION=$(echo ${INSTALL_K3S_VERSION} | sed "s/+/-/g")
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
# K3S内部CA证书的最大有效期上限，最大值被限制为3650天（10年）
CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=3650
### [ 一键安装 ] master 主节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - server --tls-san k3s-master.local --cluster-init
### [ 一键安装 ] master 从节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - server --server https://k3s-master.local:6443
### [ 一键安装 ] agent 节点
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | K3S_TOKEN=istio sh -s - agent --server https://k3s-master.local:6443
### 重载命令行别名
# $ source ~/.bashrc
# $ helm version
# $ kubectl get nodes
# $ kubectl version --output=json
# $ ctr -n k8s.io c ls
########################################################################

########################################################################
###### 离线模式
### 生成离线安装包
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | MODE=PKG ARCH=x86_64 sh
# $ curl -sfL https://renlm.github.io/sh/k3s-install.sh | MODE=PKG ARCH=aarch64 sh
### 上传离线安装包
### 解压离线安装包
# $ tar -zxvf k3s-install.x86_64.tar.gz
# $ tar -zxvf k3s-install.aarch64.tar.gz
### [ 离线安装 ] master 主节点
# $ cat k3s-install/install.sh | DOWNLOAD_SKIP=true K3S_TOKEN=istio sh -s - server --tls-san k3s-master.local --cluster-init
### [ 离线安装 ] master 从节点
# $ cat k3s-install/install.sh | DOWNLOAD_SKIP=true K3S_TOKEN=istio sh -s - server --server https://k3s-master.local:6443
### [ 离线安装 ] agent 节点
# $ cat k3s-install/install.sh | DOWNLOAD_SKIP=true K3S_TOKEN=istio sh -s - agent --server https://k3s-master.local:6443
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

# 内核参数调整
kernel_parameter_adjustment() {
  SYSCTL_P=0
  SYSTEMCTL_DAEMON_RELOAD_P=0
  __VM_OVERCOMMIT_MEMORY_NUM__=$(grep -c "^vm.overcommit_memory = 1" /etc/sysctl.conf || true)
  __NET_CORE_SOMAXCONN_NUM__=$(grep -c "^net.core.somaxconn = 4096" /etc/sysctl.conf || true)
  __FS_INOTIFY_MAX_USER_INSTANCES_NUM__=$(grep -c "^fs.inotify.max_user_instances = 4096" /etc/sysctl.conf || true)
  if [ $__VM_OVERCOMMIT_MEMORY_NUM__ -eq 0 ]; then
    SYSCTL_P=$((SYSCTL_P+1))
    printf "[ ${_GREEN_}内核参数调整${_NC_} ] vm.overcommit_memory = 1\n"
    sed -i '$a vm.overcommit_memory = 1' /etc/sysctl.conf
  fi
  if [ $__NET_CORE_SOMAXCONN_NUM__ -eq 0 ]; then
    SYSCTL_P=$((SYSCTL_P+1))
    printf "[ ${_GREEN_}内核参数调整${_NC_} ] net.core.somaxconn = 4096\n"
    sed -i '$a net.core.somaxconn = 4096' /etc/sysctl.conf
  fi
  if [ $__FS_INOTIFY_MAX_USER_INSTANCES_NUM__ -eq 0 ]; then
    SYSCTL_P=$((SYSCTL_P+1))
    printf "[ ${_GREEN_}内核参数调整${_NC_} ] fs.inotify.max_user_instances = 4096\n"
    sed -i '$a fs.inotify.max_user_instances = 4096' /etc/sysctl.conf
  fi
  # selinux
  if [ -f /etc/selinux/config ]; then
    __SELINUX_ENFORCING_NUM__=$(grep -c "^SELINUX=enforcing" /etc/selinux/config || true)
    if [ $__SELINUX_ENFORCING_NUM__ -gt 0 ]; then
      printf "[ ${_YELLOW_}selinux${_NC_} ] setenforce 0\n"
      setenforce 0 2>/dev/null || true
      sed -i "s|SELINUX=enforcing|SELINUX=Permissive|g" /etc/selinux/config
    fi
  fi
  # cgroup v1，输出为 tmpfs
  # cgroup v2，输出为 cgroup2fs
  __SYS_FS_CGROUP__=$(stat -fc %T /sys/fs/cgroup || true)
  if [ "$__SYS_FS_CGROUP__" = cgroup2fs ]; then
    __SYS_FS_CGROUP_CONTROLLERS__=$(cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers || true)
    __SYS_FS_CGROUP_CONTROLLERS_NUM__=$(echo "${__SYS_FS_CGROUP_CONTROLLERS__}" | grep -o ' ' | wc -l || true)
    __SYS_FS_CGROUP_CONTROLLERS_NUM__=$((__SYS_FS_CGROUP_CONTROLLERS_NUM__+1))
    __SYS_FS_CGROUP_CONTROLLERS_P__=0
    for i in $(seq 1 $__SYS_FS_CGROUP_CONTROLLERS_NUM__); do
      __SYS_FS_CGROUP_CONTROLLER__=$(echo "$__SYS_FS_CGROUP_CONTROLLERS__" | cut -d ' ' -f $i)
      if [ "${__SYS_FS_CGROUP_CONTROLLER__}" = cpu ] || [ "${__SYS_FS_CGROUP_CONTROLLER__}" = cpuset ] || [ "${__SYS_FS_CGROUP_CONTROLLER__}" = io ] || [ "${__SYS_FS_CGROUP_CONTROLLER__}" = memory ] || [ "${__SYS_FS_CGROUP_CONTROLLER__}" = pids ]; then
        __SYS_FS_CGROUP_CONTROLLERS_P__=$((__SYS_FS_CGROUP_CONTROLLERS_P__+1))
      fi
    done
    if [ $__SYS_FS_CGROUP_CONTROLLERS_P__ -lt 5 ]; then
      SYSTEMCTL_DAEMON_RELOAD_P=$((SYSTEMCTL_DAEMON_RELOAD_P+1))
      mkdir -p /etc/systemd/system/user@.service.d
      cat <<EOF | tee /etc/systemd/system/user@.service.d/delegate.conf >/dev/null
[Service]
Delegate=cpu cpuset io memory pids
EOF
    fi
  fi

  # 开启ipv4转发
  __IPV4_FORWARD_NUM__=$(grep -c "net.ipv4.ip_forward = 1" /etc/sysctl.conf || true)
  if [ $__IPV4_FORWARD_NUM__ -eq 0 ]; then
    SYSCTL_P=$((SYSCTL_P+1))
    printf "[ ${_GREEN_}内核参数调整${_NC_} ] 开启ipv4转发\n"
    sed -i '$a net.ipv4.ip_forward = 1' /etc/sysctl.conf
    sed -i '$a net.bridge.bridge-nf-call-iptables = 1' /etc/sysctl.conf
    sed -i '$a net.bridge.bridge-nf-call-ip6tables = 1' /etc/sysctl.conf
    modprobe bridge
    brNetfilterWcl=$(ls -l /lib/modules/$(uname -r)/kernel/net/bridge/ | grep br_netfilter | wc -l)
    if [ $brNetfilterWcl -gt 0 ]; then
      modprobe br_netfilter
    fi
  fi
  
  # systemctl daemon-reload
  if [ $SYSTEMCTL_DAEMON_RELOAD_P -gt 0 ]; then
    systemctl daemon-reload
    if [ "$__SYS_FS_CGROUP__" = cgroup2fs ]; then
      __SYS_FS_CGROUP_CONTROLLERS__=$(cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers || true)
      printf "[ ${_GREEN_}cgroup2fs${_NC_} ] ${__SYS_FS_CGROUP_CONTROLLERS__}\n"
    fi
  fi

  # sysctl -p
  if [ $SYSCTL_P -gt 0 ]; then
    printf "[ ${_YELLOW_}重载内核参数${_NC_} ] sysctl -p\n"
    sysctl -p
  fi
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
  printf "[ ${_GREEN_}开机自启${_NC_} ] ${K3S_SERVICE_FILE}\n"
  touch ${K3S_ENV_FILE}
  touch ${K3S_SERVICE_FILE}
  chmod 0600 ${K3S_ENV_FILE}
  chmod 0644 ${K3S_SERVICE_FILE}
  sh -c export | while read x v; do echo $v; done | grep -E '^(K3S|CONTAINERD)_' | tee ${K3S_ENV_FILE} >/dev/null
  sh -c export | while read x v; do echo $v; done | grep -Ei '^(NO|HTTP|HTTPS)_PROXY' | tee -a ${K3S_ENV_FILE} >/dev/null
  echo "CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=${CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS}" | tee -a ${K3S_ENV_FILE} >/dev/null
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
  printf "[ ${_GREEN_}启动服务${_NC_} ] ${SYSTEM_NAME}\n"
}
{
  ln -sf /usr/local/helm-${INSTALL_HELM_VERSION}/helm /usr/local/bin/helm
  sed -i '$a export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' ~/.bashrc
  sed -i '$a alias kubectl="k3s kubectl"' ~/.bashrc
  sed -i '$a alias ctr="k3s ctr"' ~/.bashrc
  sed -i '$a alias crictl="k3s crictl"' ~/.bashrc
  printf "${_YELLOW_}[ KUBECONFIG ]${_NC_} /etc/rancher/k3s/k3s.yaml\n"
  printf "${_YELLOW_}[ 手动执行 ]${_NC_} source ~/.bashrc\n"
}
if [ "${CMD_K3S}" = server ]; then
  printf "[ ${_GREEN_}SLEEPING${_NC_} ] 5s\n"
  sleep 5s
  helm version
  k3s kubectl get nodes
  k3s kubectl version --output=json
fi
}

# [ aarch64 | x86_64 ]
INSTALL_HELM_BIN=/usr/local/bin/helm
INSTALL_K3S_BIN=/usr/local/bin/k3s
INSTALL_K3S_IMAGES=/var/lib/rancher/k3s/agent/images/
DOWNLOADS_ROOT=/opt/k3s-install
DOWNLOADS_BASENAME=$(basename $DOWNLOADS_ROOT)
DOWNLOADER=curl
# 下载并安装
if $DOWNLOAD_SKIP; then
  DOWNLOADS_ROOT=${DOWNLOADS_BASENAME}
fi
if [ ! -f ${INSTALL_K3S_BIN} ] || [ "${MODE}" = PKG ]; then
  DOWNLOADS_FILE_SH=install.sh
  DOWNLOADS_FILE_HELM_BIN=helm/${INSTALL_HELM_VERSION}/helm-${INSTALL_HELM_VERSION}-linux-${ARCH_ALIAS}.tar.gz
  DOWNLOADS_FILE_K3S_BIN=k3s/${DOWNLOAD_K3S_VERSION}/k3s-${ARCH_ALIAS}
  DOWNLOADS_FILE_K3S_IMAGES=k3s/${DOWNLOAD_K3S_VERSION}/k3s-airgap-images-${ARCH_ALIAS}.tar
  { # 下载资源
	download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_SH} ${INSTALL_SH}
	download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_HELM_BIN} ${DOWNLOADER_URL}/${DOWNLOADS_FILE_HELM_BIN}
	download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_K3S_BIN} ${DOWNLOADER_URL}/${DOWNLOADS_FILE_K3S_BIN}
	download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_K3S_IMAGES} ${DOWNLOADER_URL}/${DOWNLOADS_FILE_K3S_IMAGES}
  }
  # 安装校验
  if [ "${MODE}" = INSTALL ]; then
    kernel_parameter_adjustment
    mkdir -p ${INSTALL_K3S_IMAGES}
    tar -zxf ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_HELM_BIN} -C /usr/local --transform="s/linux-${ARCH_ALIAS}/helm-${INSTALL_HELM_VERSION}/g"
    cp ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_K3S_BIN} ${INSTALL_K3S_BIN}
    cp ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_K3S_IMAGES} ${INSTALL_K3S_IMAGES}
    if [ -f ${INSTALL_K3S_BIN} ]; then
      printf "[ ${_GREEN_}开始安装${_NC_} ] ${INSTALL_K3S_BIN}\n"
      chmod +x ${INSTALL_K3S_BIN}
      setup_env "$@"
      create_service
    else
      printf "[ ${_RED_}安装失败${_NC_} ] ${INSTALL_K3S_BIN}\n"
      exit 1
    fi
  # 生成离线包
  else
    info "生成离线包: tar -czf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz -C ${DOWNLOADS_ROOT%/*} ${DOWNLOADS_BASENAME}"
    tar -czf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz -C ${DOWNLOADS_ROOT%/*} ${DOWNLOADS_BASENAME}
    info "离线安装 - 第1步：上传离线安装包 ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz"
    info "离线安装 - 第2步：解压离线安装包 tar -zxvf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz"
    info "master 主节点：\$ cat ${DOWNLOADS_BASENAME}/install.sh | DOWNLOAD_SKIP=true K3S_TOKEN=istio sh -s - server --tls-san k3s-master.local --cluster-init"
    info "master 从节点：\$ cat ${DOWNLOADS_BASENAME}/install.sh | DOWNLOAD_SKIP=true K3S_TOKEN=istio sh -s - server --server https://k3s-master.local:6443"
    info "agent 节点：\$ cat ${DOWNLOADS_BASENAME}/install.sh | DOWNLOAD_SKIP=true K3S_TOKEN=istio sh -s - agent --server https://k3s-master.local:6443"
  fi
else
  printf "[ ${_YELLOW_}已安装${_NC_} ] ${INSTALL_K3S_BIN}\n"
  exit 1
fi
