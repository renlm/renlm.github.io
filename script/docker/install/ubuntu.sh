#!/bin/bash
set -e
set -o noglob

# 安装
apt update
apt install -y docker.io docker-buildx docker-compose

# 配置
cat <<EOF | tee /etc/docker/daemon.json
{
  "data-root": "/home/docker",
  "features": { "buildkit" : true },
  "exec-opts": [ "native.cgroupdriver=systemd" ],
  "registry-mirrors": [ "https://docker-io.renlm.cn" ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" }
}
EOF

# 重启
systemctl daemon-reload
systemctl enable docker
systemctl restart docker