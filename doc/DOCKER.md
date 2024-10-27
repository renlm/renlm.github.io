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
	
## 私有环境
	安装 nginx、certbot
	$ apt-get update
	$ apt-get install -y nginx certbot python3-certbot-nginx
	$ systemctl enable nginx
	$ systemctl restart nginx
	$ systemctl status nginx
	
	配置证书
	$ git clone git@gitee.com:renlm/ConfigRepo.git
	$ ln -sf ConfigRepo/nginx/conf.d /etc/nginx/conf.d/
	$ nginx -v
	$ nginx -t
	$ nginx -s reload
	$ certbot --nginx --no-bootstrap
	
```	
测试并配置证书自动更新
$ certbot renew --dry-run
$ vi /etc/cron.d/certbot
0 0,12 * * * root /usr/bin/certbot renew --quiet
```

	安装 harbor
	$ wget https://github.com/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
	$ tar xvf harbor-offline-installer-v2.11.1.tgz
	$ cd harbor
	$ cp harbor.yml.tmpl harbor.yml
	$ nano harbor.yml
	$ ./install.sh
	
	安装 jenkins
	$ docker run -it --rm -p 50000:50000 \
          -v /root/.m2:/root/.m2 \
          -v /usr/bin/docker:/usr/bin/docker \
          -v /etc/docker/daemon.json:/etc/docker/daemon.json \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v /var/jenkins_home:/var/jenkins_home \
          -d jenkins
