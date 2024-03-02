# Ubuntu 22.04 64位

## 检查/etc/hosts
	修改hostname并立即生效
	$ hostname -F /etc/hostname
	将hostname配到/etc/hosts中
	$ hostname
```
192.168.0.3 JD1
192.168.16.3 JD2
192.168.16.3 rancher.renlm.cn
192.168.0.7 JD3
```
	
## 安装k3s
	https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-6-9/
	https://docs.rancher.cn/docs/k3s/installation/ha/_index/
	https://github.com/k3s-io/k3s/releases/
		
	k3s.local
	$ sed -i '$a 192.168.16.3 k3s.local' /etc/hosts

```	
# master主节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.24.17+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server --tls-san k3s.local \
    --cluster-init
```

```	
# master从节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.24.17+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server --tls-san k3s.local \
    --server https://k3s.local:6443
```

```	
# agent节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.24.17+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - agent --server https://k3s.local:6443
```

	验证k3s（master）
	$ kubectl get nodes
	$ kubectl version --output=json
	
	环境变量KUBECONFIG（master）
	https://docs.ranchermanager.rancher.io/zh/how-to-guides/new-user-guides/kubernetes-cluster-setup/k3s-for-rancher
	$ cp /etc/rancher/k3s/k3s.yaml /etc/rancher/k3s/KUBECONFIG.yaml
	$ sed -i 's/127.0.0.1:6443/k3s.local:6443/g' /etc/rancher/k3s/KUBECONFIG.yaml
	$ sed -i '$a export KUBECONFIG=/etc/rancher/k3s/KUBECONFIG.yaml' ~/.bashrc
	$ source ~/.bashrc
	
## 安装 Helm
	Helm版本支持策略
	https://helm.sh/zh/docs/topics/version_skew/
	https://github.com/helm/helm/releases/
	
	手动上传文件，下载较慢
	$ wget https://renlm.gitee.io/helm/download/helm-v3.12.3-linux-amd64.tar.gz
	$ tar -zxvf helm-v3.12.3-linux-amd64.tar.gz
	$ mv linux-amd64/helm /usr/local/bin/helm
	$ helm version

## 安装 cert-manager
	$ helm repo add jetstack https://charts.jetstack.io
	$ helm repo update
	$ kubectl get pods --namespace cert-manager
	$ helm install cert-manager jetstack/cert-manager \
		  --namespace cert-manager \
		  --create-namespace \
		  --version v1.7.1 \
		  --set installCRDs=true

## 安装 Rancher
	添加 Helm Chart 仓库
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	
	安装 rancher-stable/rancher v1.7.1
	$ kubectl -n cattle-system get deploy rancher
	$ helm install rancher rancher-stable/rancher \
        --namespace cattle-system \ 
        --create-namespace \
        --version v1.7.1 \
        --set hostname=rancher.renlm.cn \
        --set bootstrapPassword="123654" \
        --set ingress.tls.source=letsEncrypt \
        --set letsEncrypt.email=renlm@21cn.com \
        --set letsEncrypt.ingress.class=traefik

## 安装 Docker（可选）
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
	
	启动服务
	$ systemctl daemon-reload
	$ systemctl enable docker
	$ systemctl restart docker
	
	清理缓存
	$ docker system df
	$ docker system prune
	
## MTU 设置（可选）
	为保障通信，集群节点规格不一致时，需要统一MTU
	以值最小的那个节点为基准
	https://projectcalico.docs.tigera.io/networking/mtu

	查看网卡MTU
	$ ip a | grep eth0
	
	以MTU=1450为例，选用Calico MTU with VXLAN (IPv4) = 1500 - 1450 = 50
	1450 - 50 = 1400
	$ ping -s 1400 -M do {目标IP或域名}
	
```
# 常见协议 MTU 消耗
IPv4 – 20 Bytes
IPv6 – 40 Bytes
UDP – 8 Bytes
TCP – 20 Bytes
WireGuard – 32 Bytes
ICMP – 8 Bytes
PPPoE – 8 Bytes
```

```
# 修改方式一：
# 创建集群时，在附加配置的 [ Calico 配置 ] 中找到installation.calicoNetwork，添加mtu设置
installation:
  calicoNetwork:
    mtu: 1400
```
	
```
# 修改方式二：
# 命令修改
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"mtu":1400}}}'
```

