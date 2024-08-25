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
https://docs.k3s.io/zh/installation/private-registry
需要在每个节点添加
$ mkdir -p /etc/rancher/k3s
$ cat <<EOF | tee /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
    - https://docker-io.renlm.cn
  gcr.io:
    endpoint:
    - https://gcr-io.renlm.cn
  ghcr.io:
    endpoint:
    - https://ghcr-io.renlm.cn
  quay.io:
    endpoint:
    - https://quay-io.renlm.cn
EOF
```
	
## 安装 helm
	Helm版本支持策略
	https://helm.sh/docs/topics/version_skew/
	https://github.com/helm/helm/releases/
	
	手动上传文件，下载较慢
	master节点安装即可
	$ wget https://renlm.github.io/helm/helm-v3.14.4-linux-amd64.tar.gz
	$ tar -zxvf helm-v3.14.4-linux-amd64.tar.gz
	$ mv linux-amd64 /usr/local/helm-v3.14.4
	$ ln -sf /usr/local/helm-v3.14.4 /usr/local/helm
	$ sed -i '$a export PATH=/usr/local/helm/bin:$PATH' ~/.bashrc
	$ helm version

## 安装 k3s
	https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-8-6/
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
    INSTALL_K3S_VERSION=v1.28.13+k3s1 \
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
    INSTALL_K3S_VERSION=v1.28.13+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server \
    --server https://k3s.master:6443
```

```	
# agent节点
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.28.13+k3s1 \
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
	$ ctr image ls
	
## 安装 istio
	配置环境变量KUBECONFIG
	https://istio.io/latest/docs/setup/additional-setup/download-istio-release/
	https://github.com/istio/istio/releases
	
	手动上传文件，下载较慢
	istioctl安装，master节点即可
	$ wget https://renlm.github.io/helm/istio-1.22.4-linux-amd64.tar.gz
	$ tar -zxvf istio-1.22.4-linux-amd64.tar.gz
	$ mv istio-1.22.4 /usr/local/
	$ ln -sf /usr/local/istio-1.22.4 /usr/local/istio
	$ sed -i '$a export PATH=/usr/local/istio/bin:$PATH' ~/.bashrc
	$ istioctl operator init
	$ istioctl version
	
```
开始安装
$ kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: default-istiocontrolplane
spec:
  profile: default
components:
  ingressGateways:
  - name: istio-ingressgateway
    k8s:
      service:
        ports:
        - name: status-port
          port: 15021
          targetPort: 15021
        - name: http2
          nodePort: 80
          port: 80
          targetPort: 8080
        - name: https
          nodePort: 443
          port: 443
          targetPort: 8443
        - name: redis
          nodePort: 31379
          port: 6379
          targetPort: 6379
        - name: mysql
          nodePort: 31306
          port: 3306
          targetPort: 3306
        - name: amqp
          nodePort: 31672
          port: 5672
          targetPort: 5672
EOF
```

	查看
	$ kubectl get services -n istio-system
	$ kubectl get pods -n istio-system

## 安装 cert-manager
	配置环境变量KUBECONFIG
	https://cert-manager.io/docs/installation/helm/
	$ helm repo add jetstack https://charts.jetstack.io --force-update
	
	安装
	$ helm install \
	    cert-manager jetstack/cert-manager \
	    --namespace cert-manager \
	    --create-namespace \
	    --version v1.15.3 \
	    --set crds.enabled=true
	
	查看  
	$ helm -n cert-manager ls -a
	$ kubectl get pods --namespace cert-manager