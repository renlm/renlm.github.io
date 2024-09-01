# Docker（Ubuntu）

## 安装与使用
	$ apt update
	$ apt install -y docker docker-buildx docker-compose

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

	启动服务
	$ systemctl daemon-reload
	$ systemctl enable docker
	$ systemctl restart docker
	
	清理缓存
	$ docker system df
	$ docker system prune