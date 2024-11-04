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
	$ ssh-keygen -m PEM -t rsa -b 2048 -C "renlm@21cn.com"
	$ git clone git@gitee.com:renlm/ConfigRepo.git
	$ docker network create share
	$ docker network ls
	配置证书
	$ docker login --username=renlm@21cn.com registry.cn-hangzhou.aliyuncs.com
	$ docker-compose -f /root/ConfigRepo/docker/docker-compose.yml up -d
	$ docker-compose -f /root/ConfigRepo/docker/other/mysql/docker-compose.yml up -d
	$ docker-compose -f /root/ConfigRepo/docker/other/zookeeper/docker-compose.yml up -d
	$ docker-compose -f /root/ConfigRepo/docker/other/elasticsearch/docker-compose.yml up -d
	$ docker-compose -f /root/ConfigRepo/docker/other/jenkins/docker-compose.yml up -d
	$ rm -fr /etc/nginx/conf.d && ln -sf /root/ConfigRepo/nginx/conf.d /etc/nginx/conf.d
	$ ln -sf /root/ConfigRepo/nginx/modules-enabled/zookeeper.conf /etc/nginx/modules-enabled/zookeeper.conf
	$ nginx -v
	$ nginx -t
	$ nginx -s reload
	默认已开启定时续期
	$ certbot --nginx
	$ certbot certificates
	$ certbot renew --dry-run
	$ tail -f -n 100 /var/log/letsencrypt/letsencrypt.log

	安装 Harbor
	$ cd /root
	$ wget https://github.renlm.cn/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
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

```
Harbor 开机自启
$ chmod 755 /lib/systemd/system/harbor.service
$ systemctl daemon-reload
$ systemctl enable harbor
$ systemctl restart harbor
$ systemctl status harbor
$ cat <<EOF | tee /lib/systemd/system/harbor.service
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/bin/docker-compose -f /root/harbor/docker-compose.yml up
ExecStop=/usr/bin/docker-compose -f /root/harbor/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF
```

## Containerd
	$ mkdir -vp /etc/containerd
	$ containerd config default > /etc/containerd/config.toml
	添加镜像代理并重启
	$ vi /etc/containerd/config.toml
	$ systemctl daemon-reload && systemctl restart containerd

```
https://github.com/containerd/cri/blob/master/docs/registry.md

...

      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.renlm.cn".auth]
          username = "harbor"
          password = "123654"
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://docker-io.renlm.cn/v2"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
          endpoint = ["https://gcr-io.renlm.cn/v2"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."ghcr.io"]
          endpoint = ["https://ghcr-io.renlm.cn/v2"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
          endpoint = ["https://quay-io.renlm.cn/v2"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."harbor.renlm.cn"]
          endpoint = ["https://harbor.renlm.cn/v2"]

...

```
