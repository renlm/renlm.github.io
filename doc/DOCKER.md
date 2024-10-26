# Docker（Ubuntu）

## 安装与使用
	$ apt update
	$ apt install -y docker.io docker-buildx docker-compose

```
镜像加速
$ mkdir -p /etc/docker
$ cat <<EOF | tee /etc/docker/daemon.json
{
  "registry-mirrors": [ 
    "https://docker-io.renlm.cn"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "500m", "max-file": "3" },
  "features": { "buildkit" : true }
}
EOF
```

```
添加构建日志限制
$ vi /etc/systemd/system/multi-user.target.wants/docker.service
[Service]
Environment="BUILDKIT_STEP_LOG_MAX_SIZE=1073741824"
Environment="BUILDKIT_STEP_LOG_MAX_SPEED=10240000"
```

	启动服务
	$ systemctl daemon-reload
	$ systemctl enable docker
	$ systemctl restart docker
	
	清理缓存
	$ docker system df
	$ docker system prune
	
## Harbor
	证书管理
	$ apt-get update
	$ apt-get install -y certbot python3-certbot-nginx
	$ certbot --nginx

	下载并安装
	$ wget https://github.renlm.cn/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
	$ tar xvf harbor-offline-installer-v2.11.1.tgz
	$ cd harbor
	$ cp harbor.yml.tmpl harbor.yml
	$ nano harbor.yml
	./install.sh
