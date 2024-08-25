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
	$ mv linux-amd64/helm /usr/local/bin/helm
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
$ curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
    INSTALL_K3S_MIRROR=cn \
    INSTALL_K3S_VERSION=v1.28.13+k3s1 \
    K3S_TOKEN=SECRET \
    sh -s - server \
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