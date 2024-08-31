# Mygraph

## 安装 K3S | RKE2
<a href="https://renlm.github.io/doc/K3S.html" target="_blank">K3S</a>  

## 创建 Secret
	$ kubectl create namespace renlm
	$ kubectl label namespace renlm istio-injection=enabled
	服务密码  	
	$ kubectl -n renlm create secret generic mygraph \
        --from-literal=defaultPassword=PWD@20xxKplstdm^8uttm$
	阿里云镜像服务
	$ kubectl -n renlm create secret docker-registry aliyuncs \
        --docker-server=registry.cn-hangzhou.aliyuncs.com \
        --docker-username=renlm@21cn.com \
        --docker-password=PWD@20xxKplstdm^8uttm$
	  	
## 部署服务
	$ helm upgrade --install mygraph mygraph \
        --repo https://renlm.github.io/helm/repo \
        --namespace renlm --create-namespace \
        --version 1.0.1