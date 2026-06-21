# Rancher

## 2.14.2
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	$ helm fetch rancher-stable/rancher --version=2.14.2
	
	清理无用镜像
	k3s: v1.34.8+k3s1
	$ rm -f rancher-images.txt \
        && wget https://github.com/rancher/rancher/releases/download/v2.14.2/rancher-images.txt \
        && sed -i '/hardened/d' rancher-images.txt \
        && sed -i '/harvester/d' rancher-images.txt \
        && sed -i '/neuvector/d' rancher-images.txt \
        && sed -i '/rke2/d' rancher-images.txt \
        && sed -i '/cilium/d' rancher-images.txt \
        && sed -i '/longhornio/d' rancher-images.txt \
        && sed -i '/mirrored-sig-storage/d' rancher-images.txt \
        && sed -i '/mirrored-cloud-provider-vsphere/d' rancher-images.txt \
        && sed -i '/nginx/d' rancher-images.txt \
        && sed -i '/-k3s/{/v1.34.8+k3s1/!d}' rancher-images.txt
        