# K3S（Ubuntu）

## 修改 hostname
	立即生效
	$ hostname -F /etc/hostname
	$ hostname

## 检查 DNS 配置
	# Nameserver limits were exceeded
	# Too many DNS servers configured, the following entries may be ignored.
	$ cat /run/systemd/resolve/resolv.conf
	
	注释掉多余的DNS servers
	$ vi /etc/systemd/resolved.conf
	
	重启服务
	$ systemctl restart systemd-resolved
	
## 系统参数
	# failed to create fsnotify watcher: too many open files
	$ sysctl -n fs.inotify.max_user_instances
	$ echo fs.inotify.max_user_instances = 1024 | tee -a /etc/sysctl.conf && sysctl -p
	
```
Enabling CPU, CPUSET, and I/O delegation(only cgroup v2)
By default, a non-root user can only get memory controller and pids controller to be delegated.
https://rootlesscontaine.rs/getting-started/common/cgroup2/	
https://github.com/opencontainers/runc/blob/main/docs/cgroup-v2.md

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

## 私有镜像仓库配置
```
离线镜像包（备选）
https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/other-installation-methods/air-gapped-helm-cli-install/install-kubernetes
$ wget https://github.com/k3s-io/k3s/releases/download/v1.30.6+k3s1/k3s-airgap-images-amd64.tar
$ mkdir -p /var/lib/rancher/k3s/agent/images/
$ cp ./k3s-airgap-images-amd64.tar /var/lib/rancher/k3s/agent/images/
配置镜像代理（首选）
https://docs.k3s.io/zh/installation/private-registry
$ mkdir -p /etc/rancher/k3s
$ cat <<-'EOF' | tee /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
    - https://docker-io.renlm.cn
  quay.io:
    endpoint:
    - https://quay-io.renlm.cn
  gcr.io:
    endpoint:
    - https://gcr-io.renlm.cn
  ghcr.io:
    endpoint:
    - https://ghcr-io.renlm.cn
  registry.k8s.io:
    endpoint:
    - https://registry-k8s-io.renlm.cn
EOF
```
	
## 安装 helm
	Helm版本支持策略
	https://helm.sh/docs/topics/version_skew/
	https://github.com/helm/helm/releases/
	
	master节点即可（手动上传文件，下载较慢）
	$ wget https://github-io.renlm.cn/download/helm-v3.16.2-linux-amd64.tar.gz
	$ tar -zxvf helm-v3.16.2-linux-amd64.tar.gz -C /usr/local/ --transform="s/linux-amd64/helm-v3.16.2/g"
	$ ln -sf /usr/local/helm-v3.16.2 /usr/local/helm
	$ sed -i '$a export PATH=/usr/local/helm:$PATH' ~/.bashrc
	$ source ~/.bashrc
	$ helm version

## 安装 k3s
	https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-9-3/
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
# 禁用traefik，安装istio替代
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.30.6+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server \
    --disable=traefik \
    --tls-san k3s.master \
    --tls-san kubernetes.renlm.cn \
    --cluster-init
```

```	
# master从节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.30.6+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server \
    --disable=traefik \
    --server https://k3s.master:6443
```

```	
# agent节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.30.6+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - agent \
    --server https://k3s.master:6443
```

	环境变量KUBECONFIG（master）
	https://docs.ranchermanager.rancher.io/zh/how-to-guides/new-user-guides/kubernetes-cluster-setup/k3s-for-rancher
	$ cp /etc/rancher/k3s/k3s.yaml /etc/rancher/k3s/KUBECONFIG.yaml
	$ sed -i '$a export KUBECONFIG=/etc/rancher/k3s/KUBECONFIG.yaml' ~/.bashrc
	$ source ~/.bashrc
	
	验证k3s（master）
	$ kubectl get nodes
	$ kubectl version --output=json
	
	查看镜像
	$ k3s ctr image ls

## 安装 cert-manager
	配置环境变量KUBECONFIG
	https://cert-manager.io/docs/installation/helm/
	$ wget https://github.renlm.cn/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml
	$ kubectl apply -f cert-manager.yaml
	$ kubectl get pods --namespace cert-manager
	
## 安装 istio
	配置环境变量KUBECONFIG
	https://istio.io/latest/docs/setup/additional-setup/download-istio-release/
	https://github.com/istio/istio/releases
	
	master节点即可（手动上传文件，下载较慢）
	$ wget https://github-io.renlm.cn/download/istio-1.23.3-linux-amd64.tar.gz
	$ tar -zxvf istio-1.23.3-linux-amd64.tar.gz -C /usr/local/
	$ ln -sf /usr/local/istio-1.23.3 /usr/local/istio
	$ sed -i '$a export ISTIO_PATH=/usr/local/istio' ~/.bashrc
	$ sed -i '$a export PATH=$ISTIO_PATH/bin:$PATH' ~/.bashrc
	$ source ~/.bashrc
	$ istioctl version
	
	安装istio组件
	$ kubectl create namespace istio-ingress
	$ istioctl install -y --set profile=minimal
	$ wget https://github-io.renlm.cn/helm/istio.install.yaml
	$ istioctl install -y -f istio.install.yaml
	
	可视化
	$ kubectl apply -f $ISTIO_PATH/samples/addons/prometheus.yaml
	$ kubectl apply -f $ISTIO_PATH/samples/addons/kiali.yaml
	$ kubectl apply -f $ISTIO_PATH/samples/addons/loki.yaml
	
	https://istio.io/latest/zh/docs/setup/additional-setup/sidecar-injection/#manual-sidecar-injection
	$ sed -i '/sidecar.istio.io/d' $ISTIO_PATH/samples/addons/grafana.yaml
	$ istioctl kube-inject -f $ISTIO_PATH/samples/addons/grafana.yaml | kubectl apply -f -
	
	https://opentelemetry.io/docs/kubernetes/operator/
	$ kubectl create namespace observability
	$ kubectl apply -f https://github.renlm.cn/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	
	修改 IstioOperator 配置后重启
	$ kubectl get deploy -A
	$ kubectl rollout restart deploy/istio-ingressgateway -n istio-ingress
