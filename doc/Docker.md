# Docker

## 快速安装
	https://docs.ranchermanager.rancher.io/zh/getting-started/installation-and-upgrade/installation-requirements/install-docker
	$ curl https://releases.rancher.com/install-docker/20.10.sh | sh

```
	阿里云，获取加速地址并配置
	https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors
	$ mkdir -p /etc/docker
	$ tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [ "https://***.mirror.aliyuncs.com" ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "500m", "max-file": "3" },
  "features": { "buildkit" : true }
}
EOF
```
	
## 启动服务
	$ systemctl daemon-reload
	$ systemctl enable docker
	$ systemctl restart docker
	
## 清理缓存
	$ docker system df
	$ docker system prune
