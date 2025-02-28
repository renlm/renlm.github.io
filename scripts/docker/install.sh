#!/bin/bash

set -e
set -o noglob

# 脚本参数
DATA_ROOT=${@:-'/home/docker'}
OS_MIRRORS=${OS_MIRRORS:-'tencent'}
REGISTRY_MIRRORS=${REGISTRY_MIRRORS:-'https://docker.renlm.cn'}

# 内核参数
if ! grep -q '^fs.inotify.max_user_instances' /etc/sysctl.conf; then
  sed -i '$a fs.inotify.max_user_instances = 8192' /etc/sysctl.conf
fi

# 操作系统
OS_ID=`cat /etc/os-release | grep ^ID= | cut -d = -f 2 | tr -d '"'`
OS_VERSION=`cat /etc/os-release | grep ^VERSION_ID= | cut -d = -f 2 | tr -d '"'`
echo "The system is $OS_ID $OS_VERSION."
 
# 安装脚本
if [ "$OS_ID" = "ubuntu" ]; then
  curl -sfL https://github.renlm.cn/scripts/docker/install/ubuntu.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS bash -s $DATA_ROOT
elif [ "$OS_ID" = "rhel" ] || [ "$OS_ID" = "centos" ]; then
  curl -sfL https://github.renlm.cn/scripts/docker/install/rhel.sh | REGISTRY_MIRRORS=$REGISTRY_MIRRORS bash -s $DATA_ROOT
else
  echo "Does not support automatic installation of Docker."
fi

# 已安装
if [ -s /usr/bin/docker ]; then
  if [ ! -s /etc/systemd/system/multi-user.target.wants/docker.service ]; then
    systemctl enable docker
  fi
  if [ -s /etc/systemd/system/multi-user.target.wants/docker.service ]; then
    # 修改构建日志限制
    if ! grep -q '^Environment="BUILDKIT_STEP_LOG_MAX_SIZE=' /etc/systemd/system/multi-user.target.wants/docker.service; then
      sed -i '/\[Service\]/a\Environment="BUILDKIT_STEP_LOG_MAX_SPEED=10240000"' /etc/systemd/system/multi-user.target.wants/docker.service
      sed -i '/\[Service\]/a\Environment="BUILDKIT_STEP_LOG_MAX_SIZE=1073741824"' /etc/systemd/system/multi-user.target.wants/docker.service
    fi
    # WARNING: bridge-nf-call-iptables is disabled
    if ! grep -q '^net.bridge.bridge-nf-call-iptables' /etc/sysctl.conf; then
      BRIDGE_NF_CALL_IPTABLES_WARNING=$(systemctl status docker.service | grep -c 'WARNING: bridge-nf-call-iptables is disabled' || true)
      if [ $BRIDGE_NF_CALL_IPTABLES_WARNING -gt 0 ]; then
        sed -i '$a net.bridge.bridge-nf-call-iptables = 1' /etc/sysctl.conf
      fi
    fi
    # WARNING: bridge-nf-call-ip6tables is disabled
    if ! grep -q '^net.bridge.bridge-nf-call-ip6tables' /etc/sysctl.conf; then
      BRIDGE_NF_CALL_IP6TABLES_WARNING=$(systemctl status docker.service | grep -c 'WARNING: bridge-nf-call-ip6tables is disabled' || true)
      if [ $BRIDGE_NF_CALL_IP6TABLES_WARNING -gt 0 ]; then
        sed -i '$a net.bridge.bridge-nf-call-ip6tables = 1' /etc/sysctl.conf
      fi
    fi
    # Failed to built-in GetDriver graph btrfs /home/docker
    if ! grep -q 'storage-driver' /etc/docker/daemon.json; then
      GRAPH_BTRFS_WARNING=$(systemctl status docker.service | grep -c 'Failed to built-in GetDriver graph btrfs '$DATA_ROOT'' || true)
      STORAGE_DRIVER=$(systemctl status docker.service | grep -Eo 'storage-driver=\S+' | cut -d = -f 2)
      if [ $GRAPH_BTRFS_WARNING -gt 0 ]; then
        sed -i '/registry-mirrors/a\  "storage-driver": "'${STORAGE_DRIVER}'",' /etc/docker/daemon.json
      fi
    fi
    # Create network
    DOCKER_NETWORK_LS_SHARE=$(docker network ls | grep -c share || true)
    if [ $DOCKER_NETWORK_LS_SHARE -eq 0 ]; then
      docker network create share
    fi
    # Restart
    if [ -s /etc/sysctl.conf ]; then
      sysctl -p
      systemctl daemon-reload
      systemctl restart docker
      cat /etc/docker/daemon.json
    fi
    # WARNING: No swap limit support
    if [ -s /etc/default/grub ]; then
      NO_SWAP_LIMIT_WARNING=$(systemctl status docker.service | grep -c 'WARNING: No swap limit support' || true)
      if [ $NO_SWAP_LIMIT_WARNING -gt 0 ]; then
        echo "Edit GRUB_CMDLINE_LINUX and reboot."
        cp /etc/default/grub /etc/default/grub.bak
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1 \1"/g' /etc/default/grub
        update-grub
        reboot
      fi
    fi
  fi
fi
