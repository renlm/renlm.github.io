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
	
	$ wget https://renlm.gitee.io/helm/helm-v3.12.3-linux-amd64.tar.gz
	$ tar -zxvf helm-v3.12.3-linux-amd64.tar.gz
	$ mv linux-amd64/helm /usr/local/bin/helm
	$ helm version

## 安装 cert-manager
```
# 如果你手动安装了CRD，而不是在 Helm 安装命令中添加了 `--set installCRDs=true` 选项，你应该在升级 Helm Chart 之前升级 CRD 资源。
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

# 添加 Jetstack Helm 仓库
helm repo add jetstack https://charts.jetstack.io

# 更新本地 Helm Chart 仓库缓存
helm repo update

# 安装 cert-manager Helm Chart
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1
```

## 安装完 cert-manager 后，你可以通过检查 cert-manager 命名空间中正在运行的 Pod 来验证它是否已正确部署
```
kubectl get pods --namespace cert-manager

NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-5c6866597-zw7kh               1/1     Running   0          2m
cert-manager-cainjector-577f6d9fd7-tr77l   1/1     Running   0          2m
cert-manager-webhook-787858fcdb-nlzsq      1/1     Running   0          2m
```
	
## 安装 Rancher
	添加 Helm Chart 仓库
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	$ helm search repo rancher-stable/rancher

	注意放行80和443端口的访问
	注意服务器的入网带宽，需要下载一些软件包，网速太慢会导致deadline错误
	RKE Kubernetes 集群默认使用 NGINX Ingress，而 K3s Kubernetes 集群默认使用 Traefik Ingress
	http01下ingress的class值在不同环境有差异（RKE：nginx，K3s：traefik）
	
```
# 安装最新稳定版
$ helm install rancher rancher-stable/rancher \
    --namespace cattle-system --create-namespace \
    --set hostname=rancher.renlm.cn \
    --set bootstrapPassword="Pwd123654" \
    --set ingress.tls.source=letsEncrypt \
    --set letsEncrypt.email=renlm@21cn.com \
    --set letsEncrypt.ingress.class=traefik
```

```
# 安装指定版本
$ helm fetch rancher-stable/rancher --version=v2.6.9
$ helm install rancher ./rancher-2.6.9.tgz \
    --namespace cattle-system --create-namespace \
    --set hostname=rancher.renlm.cn \
    --set bootstrapPassword="Pwd123654" \
    --set ingress.tls.source=letsEncrypt \
    --set letsEncrypt.email=renlm@21cn.com \
    --set letsEncrypt.ingress.class=traefik
```

## 验证 Rancher Server 是否部署成功
```
$ kubectl -n cattle-system rollout status deploy/rancher
Waiting for deployment "rancher" rollout to finish: 0 of 3 updated replicas are available...
deployment "rancher" successfully rolled out
```
```
$ kubectl -n cattle-system get deploy rancher
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rancher   3         3         3            3           3m
```

	卸载Rancher
	$ helm uninstall rancher -n cattle-system