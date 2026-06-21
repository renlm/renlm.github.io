# Rancher
	[ 一键安装 ] master 主节点
	$ curl -sfL https://renlm.github.io/sh/k3s-install.sh | \
	    K3S_TOKEN=istio \
	    sh -s - server \
	    --disable=traefik \
	    --tls-san k3s-master.local \
	    --cluster-init
	    
	[ 一键安装 ] master 从节点
	$ curl -sfL https://renlm.github.io/sh/k3s-install.sh | \
	    K3S_TOKEN=istio \
	    sh -s - server \
	    --disable=traefik \
	    --server https://k3s-master.local:6443
	    
	[ 一键安装 ] agent 节点
	$ curl -sfL https://renlm.github.io/sh/k3s-install.sh | \
	    K3S_TOKEN=istio \
	    sh -s - agent \
	    --server https://k3s-master.local:6443

## 2.14.2
	https://github.com/rancher/rancher/releases/download/v2.14.2/rancher-images.txt
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	$ helm fetch rancher-stable/rancher --version=2.14.2
	