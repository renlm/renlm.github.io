#!/bin/sh
set -e
set -o noglob

########################################################################
# https://download.docker.com/linux/static/stable
# https://github.com/docker/buildx/releases
# https://github.com/docker/compose/releases
# https://github.com/moby/moby/blob/docker-v29.4.3/contrib/init/systemd/docker.service
# https://github.com/moby/moby/blob/docker-v29.4.3/contrib/init/systemd/docker.socket
# https://github.com/containerd/containerd/blob/v2.2.3/containerd.service
# 从 github releases 页面 Dependency Changes 中查看三者的版本匹配关系
# [ 版本匹配 ] docker: 29.4.3, buildx: 0.34.1, compose: 5.1.3
INSTALL_SH=${INSTALL_SH:-"https://renlm.github.io/sh/docker-install.sh"}
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
DOCKER_IPTABLES=${DOCKER_IPTABLES:-true}
DOCKER_IP6TABLES=${DOCKER_IP6TABLES:-false}
DOCKER_DATA_DIR=${DOCKER_DATA_DIR:-"${DOCKER_ROOT}/docker"}
CONTAINERD_DATA_DIR=${CONTAINERD_DATA_DIR:-"${DOCKER_ROOT}/containerd"}
INSTALL_DOCKER_VERSION=${INSTALL_DOCKER_VERSION:-"29.4.3"}
INSTALL_BUILDX_VERSION=${INSTALL_BUILDX_VERSION:-"0.34.1"}
INSTALL_COMPOSE_VERSION=${INSTALL_COMPOSE_VERSION:-"5.1.3"}
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
# $ curl -sfL https://renlm.github.io/sh/docker-install.sh | DOCKER_ROOT=/data DOCKER_IPTABLES=true sh
########################################################################

########################################################################
###### 离线模式
### 生成离线安装包
# $ curl -sfL https://renlm.github.io/sh/docker-install.sh | MODE=PKG ARCH=x86_64 sh
# $ curl -sfL https://renlm.github.io/sh/docker-install.sh | MODE=PKG ARCH=aarch64 sh
### 上传离线安装包
### 解压离线安装包
# $ tar -zxvf docker-install.x86_64.tar.gz
# $ tar -zxvf docker-install.aarch64.tar.gz
### 离线安装
# $ cat docker-install/install.sh | DOWNLOAD_SKIP=true DOCKER_ROOT=/data DOCKER_IPTABLES=true sh
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
NOT_INNER_SH=${NOT_INNER_SH:-true}
if [ "$MODE" = INSTALL ] || [ "$MODE" = PKG ]; then
  if [ "$MODE" = PKG ]; then
    DOWNLOAD_SKIP=false
  fi
  {
    [ "$NOT_INNER_SH" = true ] && info "MODE: $MODE" || true
    [ "$NOT_INNER_SH" = true ] && info "DOWNLOAD_SKIP: $DOWNLOAD_SKIP" || true
  }
else
  fatal "Unknown MODE: $MODE, INSTALL or PKG"
fi
if [ "$ARCH" = auto ] || [ "$ARCH" = x86_64 ] || [ "$ARCH" = aarch64 ]; then
  if [ "$ARCH" = auto ]; then
    if uname -m | grep -q aarch64; then
      ARCH=aarch64
    else
      ARCH=x86_64
    fi
  fi
  if [ "$ARCH" = aarch64 ]; then
    ARCH_ALIAS=arm64
  fi
  if [ "$ARCH" = x86_64 ]; then
    ARCH_ALIAS=amd64
  fi
  {
    [ "$NOT_INNER_SH" = true ] && info "ARCH: $ARCH" || true
    [ "$NOT_INNER_SH" = true ] && info "ARCH_ALIAS: $ARCH_ALIAS" || true
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

# 设置开机自启
create_service() {
  DOCKER_SERVICE_FILE="/etc/systemd/system/docker.service"
  DOCKER_SOCKET_FILE="/etc/systemd/system/docker.socket"
  DOCKER_CONTAINERD_FILE="/etc/systemd/system/containerd.service"
  printf "[ ${_GREEN_}开机自启${_NC_} ] ${DOCKER_SERVICE_FILE}\n"
  mkdir -p ${DOCKER_CONFIG%/*}
  touch ${DOCKER_CONFIG}
  touch ${DOCKER_SERVICE_FILE}
  touch ${DOCKER_SOCKET_FILE}
  touch ${DOCKER_CONTAINERD_FILE}
  chmod 0600 ${DOCKER_CONFIG}
  chmod 0644 ${DOCKER_SERVICE_FILE}
  chmod 0644 ${DOCKER_SOCKET_FILE}
  chmod 0644 ${DOCKER_CONTAINERD_FILE}
  cat <<EOF | tee ${DOCKER_SERVICE_FILE} >/dev/null
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target nss-lookup.target docker.socket firewalld.service containerd.service time-set.target
Wants=network-online.target containerd.service
Requires=docker.socket
StartLimitBurst=3
StartLimitIntervalSec=60

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=${INSTALL_DOCKER_ROOT}/dockerd --iptables=${DOCKER_IPTABLES} --ip6tables=${DOCKER_IP6TABLES} --default-ulimit nofile=655350:655350 --config-file ${DOCKER_CONFIG} -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target

EOF
  cat <<EOF | tee ${DOCKER_SOCKET_FILE} >/dev/null
[Unit]
Description=Docker Socket for the API

[Socket]
# If /var/run is not implemented as a symlink to /run, you may need to
# specify ListenStream=/var/run/docker.sock instead.
ListenStream=/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target

EOF
  cat <<EOF | tee ${DOCKER_CONTAINERD_FILE} >/dev/null
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target dbus.service

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=${INSTALL_DOCKER_ROOT}/containerd --config ${CONTAINERD_CONFIG}

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target

EOF
  cat <<EOF | tee ${DOCKER_CONFIG} >/dev/null
{
  "data-root": "$DOCKER_DATA_DIR",
  "features": {"buildkit":true},
  "log-driver": "json-file",
  "log-opts": {"max-size":"300m","max-file":"10"},
  "registry-mirrors": ["http://registry.local:5000"],
  "insecure-registries": ["registry.local:5000"]
}

EOF
if [ ! -f ${CONTAINERD_CONFIG} ]; then
  mkdir -p ${CONTAINERD_CONFIG%/*}
  containerd config default | sed "s|^root = '/var/lib/containerd'|root = '${CONTAINERD_DATA_DIR}'|g" > ${CONTAINERD_CONFIG}
  chmod 0600 ${CONTAINERD_CONFIG}
fi
{
  groupadd --system docker 2>/dev/null || true
  systemctl daemon-reload
  systemctl enable containerd
  systemctl enable docker.socket
  systemctl enable docker
  systemctl restart containerd
  systemctl restart docker.socket
  systemctl restart docker
  printf "[ ${_GREEN_}启动服务${_NC_} ] containerd\n"
  printf "[ ${_GREEN_}启动服务${_NC_} ] docker.socket\n"
  printf "[ ${_GREEN_}启动服务${_NC_} ] docker\n"
  TXT_LINE=0
  while IFS= read -r line; do
    TXT_LINE=$((TXT_LINE+1))
    if [ $TXT_LINE -gt 1 ]; then
      line_val=$(echo "$line" | cut -d "=" -f2)
      line_tar=$(echo "$line_val" | cut -d "@" -f2)
      docker load -i ${DOWNLOADS_ROOT}/docker/images/tools-${ARCH_ALIAS}/$line_tar
    fi
  done < ${DOWNLOADS_ROOT}/docker/images/tools-${ARCH_ALIAS}/tools-${ARCH_ALIAS}.txt
}
}

# [ aarch64 | x86_64 ]
INSTALL_DOCKER_ROOT=/usr/bin
INSTALL_DOCKER_BIN=${INSTALL_DOCKER_ROOT}/docker
DOCKER_CONFIG=/etc/docker/daemon.json
CONTAINERD_CONFIG=/etc/containerd/config.toml
DOWNLOADS_ROOT=/opt/docker-install
DOWNLOADS_BASENAME=$(basename $DOWNLOADS_ROOT)
DOWNLOADER=curl
# 下载并安装
if $DOWNLOAD_SKIP; then
  DOWNLOADS_ROOT=${DOWNLOADS_BASENAME}
else
  rm -fr ${DOWNLOADS_ROOT}
fi
if [ ! -f ${INSTALL_DOCKER_BIN} ] || [ "${MODE}" = PKG ]; then
  DOWNLOADS_FILE_SH=install.sh
  DOWNLOADS_FILE_DOCKER_BIN=docker/${INSTALL_DOCKER_VERSION}/${ARCH}/docker-${INSTALL_DOCKER_VERSION}.tgz
  DOWNLOADS_FILE_BUILDX_BIN=docker/buildx/${INSTALL_BUILDX_VERSION}/buildx-v${INSTALL_BUILDX_VERSION}.linux-${ARCH_ALIAS}
  DOWNLOADS_FILE_COMPOSE_BIN=docker/compose/${INSTALL_COMPOSE_VERSION}/docker-compose-linux-${ARCH}
  TOOLS_IMAGES_TAR=docker/images/tools-${ARCH_ALIAS}.tar.gz
  { # 下载资源
    download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_SH} ${INSTALL_SH}
    download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_DOCKER_BIN} ${DOWNLOADER_URL}/${DOWNLOADS_FILE_DOCKER_BIN}
    download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_BUILDX_BIN} ${DOWNLOADER_URL}/${DOWNLOADS_FILE_BUILDX_BIN}
    download ${DOWNLOADS_ROOT}/${DOWNLOADS_FILE_COMPOSE_BIN} ${DOWNLOADER_URL}/${DOWNLOADS_FILE_COMPOSE_BIN}
    download ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR} ${DOWNLOADER_URL}/${TOOLS_IMAGES_TAR}
  }
  # 安装校验
  if [ "${MODE}" = INSTALL ]; then
    kernel_parameter_adjustment
    mkdir -p /usr/libexec/docker/cli-plugins
    tar -zxf ${DOWNLOADS_ROOT}/${TOOLS_IMAGES_TAR} -C ${DOWNLOADS_ROOT}/docker/images
    tar -zxf ${DOWNLOADS_ROOT}/docker/${INSTALL_DOCKER_VERSION}/${ARCH}/docker-${INSTALL_DOCKER_VERSION}.tgz --strip-components=1 -C ${INSTALL_DOCKER_ROOT}
    cp ${DOWNLOADS_ROOT}/docker/buildx/${INSTALL_BUILDX_VERSION}/buildx-v${INSTALL_BUILDX_VERSION}.linux-${ARCH_ALIAS} /usr/libexec/docker/cli-plugins/docker-buildx
    cp ${DOWNLOADS_ROOT}/docker/compose/${INSTALL_COMPOSE_VERSION}/docker-compose-linux-${ARCH} /usr/libexec/docker/cli-plugins/docker-compose
    ln -sf /usr/libexec/docker/cli-plugins/docker-compose ${INSTALL_DOCKER_ROOT}/docker-compose
    ln -sf /usr/libexec/docker/cli-plugins/docker-buildx ${INSTALL_DOCKER_ROOT}/docker-buildx
    chmod +x ${INSTALL_DOCKER_ROOT}/docker-compose
    chmod +x ${INSTALL_DOCKER_ROOT}/docker-buildx
    if [ -f ${INSTALL_DOCKER_BIN} ]; then
      printf "[ ${_GREEN_}开始安装${_NC_} ] ${INSTALL_DOCKER_BIN}\n"
      create_service
    else
      printf "[ ${_RED_}安装失败${_NC_} ] ${INSTALL_DOCKER_BIN}\n"
      exit 1
    fi
  # 生成离线包
  else
    [ "$NOT_INNER_SH" = true ] && info "生成离线包: tar -czf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz -C ${DOWNLOADS_ROOT%/*} ${DOWNLOADS_BASENAME}" || true
    tar -czf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz -C ${DOWNLOADS_ROOT%/*} ${DOWNLOADS_BASENAME}
    [ "$NOT_INNER_SH" = true ] && info "离线安装 - 第1步：上传离线安装包 ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz" || true
    [ "$NOT_INNER_SH" = true ] && info "离线安装 - 第2步：解压离线安装包 tar -zxvf ${DOWNLOADS_BASENAME}.${ARCH}.tar.gz" || true
    [ "$NOT_INNER_SH" = true ] && info "\$ cat ${DOWNLOADS_BASENAME}/install.sh | DOWNLOAD_SKIP=true DOCKER_ROOT=/data DOCKER_IPTABLES=true sh" || true
  fi
else
  printf "[ ${_YELLOW_}已安装${_NC_} ] ${INSTALL_DOCKER_BIN}\n"
  exit 1
fi
