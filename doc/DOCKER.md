# Docker（Ubuntu）

## 安装与使用
	$ apt update
	$ apt install -y docker.io docker-buildx docker-compose

```
镜像加速
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
	$ apt-get install -y nginx certbot python3-certbot-nginx
	$ systemctl enable nginx
	$ systemctl restart nginx
	$ systemctl status nginx
	
	开发组件
	$ ssh-keygen -m PEM -t rsa -b 2048 -C "renlm@21cn.com" -N ""
	$ git clone git@gitee.com:renlm/ConfigRepo.git
	$ docker network create share
	$ docker network ls
	$ cd /root/ConfigRepo/docker
	$ docker-compose down
	$ docker-compose up -d
	$ docker-compose restart
	$ docker logs -f --tail=100 postgres

	安装 harbor
	$ cd /root
	$ wget https://github.com/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
	$ tar xvf harbor-offline-installer-v2.11.1.tgz
	$ cd /root/harbor \
        && cp harbor.yml.tmpl harbor.yml \
        && sed -i 's/reg.mydomain.com/harbor.renlm.cn/g' harbor.yml \
        && sed -i 's/port: 80/port: 8443/g' harbor.yml \
        && sed -i 's/https:/# https:/g' harbor.yml \
        && sed -i 's/port: 443/# port: 443/g' harbor.yml \
        && sed -i 's/certificate:/# certificate:/g' harbor.yml \
        && sed -i 's/private_key:/# private_key:/g' harbor.yml \
        && sed -i 's@# external_url: # https://harbor.renlm.cn:8433@external_url: https://harbor.renlm.cn@g' harbor.yml \
        && sed -i 's/harbor_admin_password: Harbor12345/harbor_admin_password: 123654/g' harbor.yml \
        && ./install.sh
	
	配置证书
	$ docker-compose -f /root/ConfigRepo/docker/docker-compose.yml up -d redis
	$ docker-compose -f /root/ConfigRepo/docker/docker-compose.yml up -d rabbitmq
	$ docker-compose -f /root/ConfigRepo/docker/docker-compose.yml up -d postgres
	$ cd /root/ConfigRepo/docker
	$ docker-compose up -d
	$ ln -sf /root/ConfigRepo/nginx/conf.d/rabbitmq.renlm.cn.conf /etc/nginx/conf.d/rabbitmq.renlm.cn.conf
	$ ln -sf /root/ConfigRepo/nginx/conf.d/config.renlm.cn.conf /etc/nginx/conf.d/config.renlm.cn.conf
	$ ln -sf /root/ConfigRepo/nginx/conf.d/eureka.renlm.cn.conf /etc/nginx/conf.d/eureka.renlm.cn.conf
	$ ln -sf /root/ConfigRepo/nginx/conf.d/gateway.renlm.cn.conf /etc/nginx/conf.d/gateway.renlm.cn.conf
	$ ln -sf /root/ConfigRepo/nginx/conf.d/jenkins.renlm.cn.conf /etc/nginx/conf.d/jenkins.renlm.cn.conf
	$ ln -sf /root/ConfigRepo/nginx/conf.d/harbor.renlm.cn.conf /etc/nginx/conf.d/harbor.renlm.cn.conf
	$ ln -sf /root/ConfigRepo/nginx/conf.d/elasticsearch.renlm.cn.conf /etc/nginx/conf.d/elasticsearch.renlm.cn.conf
	$ nginx -v
	$ nginx -t
	$ nginx -s reload
	$ certbot --nginx
	自动更新
	$ certbot certificates
	$ certbot renew --dry-run
	$ sed -i '$a 0 0,12 * * * root /usr/bin/certbot renew --quiet' /etc/cron.d/certbot
	$ tail -f -n 100 /var/log/letsencrypt/letsencrypt.log
