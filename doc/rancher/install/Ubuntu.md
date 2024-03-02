# tidb
TiDB的安装配置与使用

## 软硬件环境需求
	https://docs.pingcap.com/zh/tidb/stable/hardware-and-software-requirements
	操作系统：OpenEuler 22.03 64位
	
## 更换系统镜像源
	https://www.openeuler.org/zh/mirror/list/
	$ cat /etc/os-release
	$ cd /etc/yum.repos.d
	$ cp -a openEuler-22.repo openEuler-22.repo.bak
	$ sed -i 's?http://mirrors.jdcloudcs.com/openeuler?https://mirrors.aliyun.com/openeuler?g' openEuler-22.repo
	$ yum makecache
	
## 安装k3s
	https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-6-9/
	https://docs.rancher.cn/docs/k3s/installation/ha/_index/
	https://github.com/k3s-io/k3s/releases/
		
	restorecon
	$ yum -y install policycoreutils
	
	k3s.local
	$ sed -i '$a 192.168.0.11 k3s.local' /etc/hosts

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
	
	AMD：x86_64 或 i686
	ARM：armv7l、aarch64 或 arm64
	$ lscpu | grep Architecture

```
# 手动上传文件，下载较慢
$ tar -zxvf helm-v3.12.3-linux-amd64.tar.gz
$ mv linux-amd64/helm /usr/local/bin/helm
$ helm version
```

## 安装 cert-manager
	https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/other-installation-methods/rancher-behind-an-http-proxy/install-rancher
	https://cert-manager.io/docs/usage/certificate/#creating-certificate-resources
	
	如果你手动安装了CRD，而不是在 Helm 安装命令中添加了 `--set installCRDs=true` 选项，你应该在升级 Helm Chart 之前升级 CRD 资源。
	$ kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
	下载文件后上传安装CRD（服务器上github访问不稳定时）
	$ kubectl apply -f cert-manager.crds.yaml
	
	添加 Jetstack Helm 仓库
	$ helm repo add jetstack https://charts.jetstack.io
	
	更新本地 Helm Chart 仓库缓存
	$ helm repo update

```
# 安装 cert-manager Helm Chart
$ helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1
```

```
安装完 cert-manager 后，你可以通过检查 cert-manager 命名空间中正在运行的 Pod 来验证它是否已正确部署
$ kubectl get pods --namespace cert-manager

NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-7c99ccbdd4-892nv              1/1     Running   0          3m7s
cert-manager-cainjector-799957469f-8zd9k   1/1     Running   0          3m7s
cert-manager-webhook-569f57c458-pqh2b      1/1     Running   0          3m7s
```

## 安装rancher
	https://ranchermanager.docs.rancher.com/zh/pages-for-subheaders/install-upgrade-on-a-kubernetes-cluster
	添加 Helm Chart 仓库
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	$ helm search repo rancher-stable/rancher

	注意放行80和443端口的访问
	注意服务器的入网带宽，需要下载一些软件包，网速太慢会导致deadline错误
	RKE Kubernetes 集群默认使用 NGINX Ingress，而 K3s Kubernetes 集群默认使用 Traefik Ingress
	http01下ingress的class值在不同环境有差异（RKE：nginx，K3s：traefik）

```
# 安装指定版本
$ helm fetch rancher-stable/rancher --version=v2.6.9
$ helm install rancher ./rancher-2.6.9.tgz \
    --namespace cattle-system --create-namespace \
    --set hostname=tidb.renlm.cn \
    --set bootstrapPassword="tidb" \
    --set ingress.tls.source=letsEncrypt \
    --set letsEncrypt.email=renlm@21cn.com \
    --set letsEncrypt.ingress.class=traefik
```

```
# 验证 Rancher Server 是否部署成功
$ kubectl -n cattle-system rollout status deploy/rancher
Waiting for deployment "rancher" rollout to finish: 0 of 3 updated replicas are available...
deployment "rancher" successfully rolled out

$ kubectl -n cattle-system get deploy rancher
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rancher   3         3         3            3           3m

# 卸载Rancher
$ helm uninstall rancher -n cattle-system
```

## 安装docker（可选）
```
	阿里云，获取加速地址并配置
	# https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors
	$ mkdir -p /etc/docker
	$ tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [ "https://chbxt8wx.mirror.aliyuncs.com" ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "500m", "max-file": "3" },
  "features": { "buildkit" : true }
}
EOF
```

	安装并启用
	$ dnf search docker
	$ dnf install -y docker-engine
	$ dnf install -y docker-compose
	$ systemctl enable docker	
	$ systemctl daemon-reload
	$ systemctl restart docker
	
	新建用户
	$ adduser renlm
	$ passwd renlm
	$ usermod -aG docker renlm
	$ newgrp docker
	
	清理缓存，降低磁盘占用
	$ su - renlm
	$ docker system df
	$ docker system prune
	
## 关闭防火墙
	通过安全组的入站规则进行端口访问控制
	$ systemctl enable firewalld
	$ systemctl start firewalld
	$ firewall-cmd --zone=public --list-ports
	$ firewall-cmd --zone=public --add-port=80/tcp --permanent
	$ firewall-cmd --zone=public --remove-port=80/tcp --permanent
	$ firewall-cmd --reload
	$ systemctl stop firewalld
	$ systemctl disable firewalld
	
## 检测及安装 NTP 服务
	https://docs.pingcap.com/zh/tidb/stable/check-before-deployment
	$ systemctl status chronyd.service
	$ chronyc tracking

## 创建k8s集群
	https://docs.pingcap.com/zh/tidb/stable/hardware-and-software-requirements
	按标准<开发及测试环境>创建集群
	集群名称tidb，Kubernetes 版本：v1.24.17+rke2r1
		
## 部署tidb
	https://docs.pingcap.com/zh/tidb-in-kubernetes/dev/deploy-tidb-operator
	将模板仓库添加到tidb集群
	打开Git Bash，创建Github的SSH keys
	$ clip < ~/.ssh/id_rsa.pub
	$ clip < ~/.ssh/id_rsa
	
	