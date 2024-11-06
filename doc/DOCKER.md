# Docker（Ubuntu）

## 安装与使用
	$ apt update
	$ apt install -y tree docker.io docker-buildx docker-compose

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
	$ docker-compose -f /root/ConfigRepo/docker/other/mygraph/docker-compose.yml up -d
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

## Containerd（可选）
	安装crictl
	https://github.com/kubernetes-sigs/cri-tools
	$ VERSION="v1.31.1"
	$ wget https://github.renlm.cn/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
	$ tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
	$ rm -f crictl-$VERSION-linux-amd64.tar.gz

```
https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md
$ cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: true
pull-image-on-create: false
EOF
```
	
	镜像代理
	$ mkdir -p /etc/containerd/certs.d/{docker.io,gcr.io,ghcr.io,quay.io,registry.k8s.io}
	$ cd /etc/containerd/certs.d
	$ wget https://github-io.renlm.cn/download/containerd/registry-certs.d/docker.io/hosts.toml -O docker.io/hosts.toml
	$ wget https://github-io.renlm.cn/download/containerd/registry-certs.d/gcr.io/hosts.toml -O gcr.io/hosts.toml
	$ wget https://github-io.renlm.cn/download/containerd/registry-certs.d/ghcr.io/hosts.toml -O ghcr.io/hosts.toml
	$ wget https://github-io.renlm.cn/download/containerd/registry-certs.d/quay.io/hosts.toml -O quay.io/hosts.toml
	$ wget https://github-io.renlm.cn/download/containerd/registry-certs.d/registry.k8s.io/hosts.toml -O registry.k8s.io/hosts.toml

```
$ ctr image pull --hosts-dir /etc/containerd/certs.d docker.io/nginx:latest
$ ctr image pull --hosts-dir /etc/containerd/certs.d gcr.io/kubebuilder/kube-rbac-proxy:v0.13.1
$ ctr image pull --hosts-dir /etc/containerd/certs.d ghcr.io/graalvm/jdk-community:23.0.1
$ ctr image pull --hosts-dir /etc/containerd/certs.d quay.io/jetstack/cert-manager-webhook:v1.16.1
$ ctr image pull --hosts-dir /etc/containerd/certs.d registry.k8s.io/pause:3.8
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
├── docker.io
│   └── hosts.toml
├── gcr.io
│   └── hosts.toml
├── ghcr.io
│   └── hosts.toml
├── quay.io
│   └── hosts.toml
└── registry.k8s.io
    └── hosts.toml
```

```
修改配置并重启
https://github.com/containerd/containerd/blob/main/docs/cri/registry.md
$ containerd --version
$ containerd config default > /etc/containerd/config.toml
$ vi /etc/containerd/config.toml
$ service containerd restart
$ crictl image ls
$ crictl pull docker.io/nginx:latest
$ crictl pull gcr.io/kubebuilder/kube-rbac-proxy:v0.13.1
$ crictl pull ghcr.io/graalvm/jdk-community:23.0.1
$ crictl pull quay.io/jetstack/cert-manager-webhook:v1.16.1
$ crictl pull registry.k8s.io/pause:3.8

In containerd 1.x
...

    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"

...

```
