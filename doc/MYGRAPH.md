# Mygraph

## 安装 K3S | RKE2
<a href="https://renlm.github.io/doc/K3S.html" target="_blank">K3S</a>  

## 创建 Secret
	$ kubectl create namespace renlm
	$ kubectl label namespace renlm istio-injection=enabled
	阿里云镜像服务个人版
	$ kubectl -n renlm create secret docker-registry aliyuncs \
	  	--docker-server=registry.cn-hangzhou.aliyuncs.com \
	  	--docker-username=USER \
	  	--docker-password=PWD
	  	
## 部署服务
	$ helm upgrade --install mygraph mygraph \
        --repo https://renlm.github.io/helm/repo \
        --namespace renlm --create-namespace \
        --version 1.0.1