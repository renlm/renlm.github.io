# Rancher v2.8.3 + Ubuntu 22.04

## 检查/etc/hosts
	修改hostname并立即生效
	$ hostname -F /etc/hostname
	将hostname配到/etc/hosts中
	$ hostname
```
192.168.0.3 JD1
192.168.16.3 JD2
192.168.0.7 JD3
192.168.16.3 rancher.renlm.cn
```

## 检查DNS配置
	# Nameserver limits were exceeded
	# Too many DNS servers configured, the following entries may be ignored.
	$ cat /run/systemd/resolve/resolv.conf
	
	注释掉多余的DNS servers
	$ vi /etc/systemd/resolved.conf
	
	重启服务
	$ systemctl restart systemd-resolved
	$ systemctl enable systemd-resolved
	
## 系统参数
	# failed to create fsnotify watcher: too many open files
	$ sysctl -n fs.inotify.max_user_instances
	$ echo fs.inotify.max_user_instances = 1024 | tee -a /etc/sysctl.conf && sysctl -p
	
```
Enabling CPU, CPUSET, and I/O delegation(only cgroup v2)
By default, a non-root user can only get memory controller and pids controller to be delegated.
https://rootlesscontaine.rs/getting-started/common/cgroup2/	

对于 cgroup v1，输出为 tmpfs
对于 cgroup v2，输出为 cgroup2fs
$ stat -fc %T /sys/fs/cgroup

$ cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers
memory pids

To allow delegation of other controllers such as cpu, cpuset, and io, run the following commands:
$ mkdir -p /etc/systemd/system/user@.service.d
$ cat <<EOF | tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
$ systemctl daemon-reload
```
	
## 安装k3s
	https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-8-3/
	https://docs.rancher.cn/docs/k3s/installation/ha/_index/
	https://github.com/k3s-io/k3s/releases/
	
	restorecon
	$ apt-get update
	$ apt-get install -y policycoreutils
	
	设置主节点host(192.168.16.3)
	安装的每个节点机器执行
	$ sed -i '$a 192.168.16.3 k3s.master' /etc/hosts
		
```	
# master主节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.27.13+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server --tls-san k3s.master \
    --cluster-init
```

```	
# master从节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.27.13+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server --tls-san k3s.master \
    --server https://k3s.master:6443
```

```	
# agent节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.27.13+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - agent --server https://k3s.master:6443
```

	环境变量KUBECONFIG（master）
	https://docs.ranchermanager.rancher.io/zh/how-to-guides/new-user-guides/kubernetes-cluster-setup/k3s-for-rancher
	$ cp /etc/rancher/k3s/k3s.yaml /etc/rancher/k3s/KUBECONFIG.yaml
	$ sed -i 's/127.0.0.1:6443/k3s.master:6443/g' /etc/rancher/k3s/KUBECONFIG.yaml
	$ sed -i '$a export KUBECONFIG=/etc/rancher/k3s/KUBECONFIG.yaml' ~/.bashrc
	$ source ~/.bashrc
	
	验证k3s（master）
	$ kubectl get nodes
	$ kubectl version --output=json
	
## 安装 helm
	Helm版本支持策略
	https://helm.sh/zh/docs/topics/version_skew/
	https://github.com/helm/helm/releases/
	
	手动上传文件，下载较慢
	$ wget https://renlm.github.io/helm/download/helm-v3.12.3-linux-amd64.tar.gz
	$ tar -zxvf helm-v3.12.3-linux-amd64.tar.gz
	$ mv linux-amd64/helm /usr/local/bin/helm
	$ helm version

## 安装 cert-manager
	配置环境变量KUBECONFIG
	https://cert-manager.io/docs/installation/helm/
	$ helm repo add jetstack https://charts.jetstack.io
	$ helm repo update
	$ kubectl get pods --namespace cert-manager
	$ helm install cert-manager jetstack/cert-manager \
		  --namespace cert-manager \
		  --create-namespace \
		  --version v1.14.5 \
		  --set installCRDs=true

## 安装 rancher
	添加 Helm Chart 仓库
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	
	$ kubectl -n cattle-system get deploy rancher
	$ kubectl -n cattle-system rollout status deploy/rancher
	
	安装 rancher-stable/rancher v2.8.3
	注意：要保障hostname及其一级域名的DNS解析均指向部署服务器
	$ kubectl create namespace cattle-system
	$ helm fetch rancher-stable/rancher --version=v2.8.3
	$ helm install rancher ./rancher-2.8.3.tgz \
        --namespace cattle-system \
        --set hostname=rancher.renlm.cn \
        --set bootstrapPassword="PWD" \
        --set ingress.tls.source=letsEncrypt \
        --set letsEncrypt.email=renlm@21cn.com \
        --set letsEncrypt.ingress.class=traefik
	
## SSL证书（可选）
	登录Rancher Kubectl Shell控制台
	https://cert-manager.io/docs/usage/certificate/#creating-certificate-resources
	$ kubectl apply -f https://renlm.github.io/helm/yaml/tls.yaml

## 安装 docker（可选）
	https://download.docker.com/linux/static/stable/x86_64/
	https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/installation-requirements/install-docker
	$ curl https://releases.rancher.com/install-docker/23.0.6.sh | sh

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
	https://docs.rke2.io/install/network_options

	查看网卡MTU
	$ ip a | grep eth0
	
	MTU检测
	$ ping -s 1451 -M do {目标IP或域名}
	以MTU=1450为例，选用Calico MTU with VXLAN (IPv4) = 1500 - 1450 = 50
	集群MTU应设置为：1450 - 50 = 1400
	
```
# 协议消耗
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
# 创建集群时，[附加配置] 添加参数
installation:
  calicoNetwork:
    mtu: 1400
```
	
```
# 修改方式二：
# 命令修改
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"mtu":1400}}}'
```
