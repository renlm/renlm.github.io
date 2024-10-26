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
	# 1. 下载Harbor安装包
	wget https://github.renlm.cn/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
	 
	# 2. 解压安装包
	tar xvf harbor-offline-installer-v2.11.1.tgz
	 
	# 3. 进入解压后的目录
	cd harbor
	 
	# 4. 修改配置文件harbor.yml，根据需要配置
	cp harbor.yml.tmpl harbor.yml
	# 使用编辑器打开harbor.yml，比如使用nano：
	nano harbor.yml
	# 修改例如hostname，port，admin密码等配置
	 
	# 5. 安装Harbor
	./install.sh
	 
	# 安装完成后，Harbor将启动并运行
	