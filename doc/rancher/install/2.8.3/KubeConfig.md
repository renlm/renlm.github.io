# 客户端配置生成

## 环境配置
	# Rancher v2.8.3
	v1.27.13+k3s1
	cert-manager v1.7.1
	
	# RKE2
	v1.24.17
	
## Ingress-nginx 
	登录Rancher Kubectl Shell控制台
	启用allow-snippet-annotations（默认false）
	https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
	https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
	$ kubectl get cm -A | grep ingress
	$ kubectl edit cm -n kube-system rke2-ingress-nginx-controller
	
## 安装 cert-manager
	登录Rancher Kubectl Shell控制台
	https://cert-manager.io/docs/installation/helm/
	$ helm repo add jetstack https://charts.jetstack.io
	$ helm repo update
	$ kubectl get pods --namespace cert-manager
	$ helm install cert-manager jetstack/cert-manager \
		  --namespace cert-manager \
		  --create-namespace \
		  --version v1.7.1 \
		  --set installCRDs=true

## SSL证书（可选）
	登录Rancher Kubectl Shell控制台
	https://cert-manager.io/docs/usage/certificate/#creating-certificate-resources
	$ kubectl apply -f https://renlm.github.io/helm/yaml/tls.yaml
	
## 镜像密文（可选）
	# 同一命名空间下使用
	$ kubectl create namespace renlm
	
	# kubectl -n renlm get secret aliyuncs --output="jsonpath={.data.\.dockerconfigjson}" | base64 -d
	$ kubectl -n renlm create secret docker-registry aliyuncs \
	  	--docker-server=registry.cn-hangzhou.aliyuncs.com \
	  	--docker-username=renlm@21cn.com \
	  	--docker-password=PWD

## KubeConfig
	登录机器
	https://kubernetes.io/zh-cn/docs/tasks/tls/managing-tls-in-a-cluster/
	https://kubernetes.io/zh-cn/docs/reference/access-authn-authz/certificate-signing-requests/
	https://kubernetes.io/zh-cn/docs/reference/kubernetes-api/authorization-resources/role-binding-v1/
	$ apt-get update
	$ apt-get install -y openssl golang-cfssl jq
	
```	
# 环境变量
sed -i '/^export[[:space:]]KUBECONFIG.*var.*lib.*rancher.*rke2/d' ~/.bashrc
sed -i '/^export[[:space:]]PATH.*var.*lib.*rancher.*rke2/d' ~/.bashrc
sed -i '$a export KUBECONFIG=/var/lib/rancher/rke2/server/cred/api-server.kubeconfig' ~/.bashrc
sed -i '$a export PATH=$PATH:/var/lib/rancher/rke2/bin' ~/.bashrc
source ~/.bashrc
```
	
```
# 运维团队
# 集群角色：cluster-admin
# 命令动作：new、export
curl -sfL https://renlm.github.io/script/sh/KubeConfig.sh | \
  SERVER=https://kubernetes.renlm.cn \
  CLUSTER=pubyun \
  NAMESPACE=renlm \
  CONTEXT=test \
  USER=devops \
  IMPERSONATE_USER=devops-cluster-admin \
  bash -s cluster-admin - new
```

```
# 开发团队
# 集群角色：admin
# 命令动作：new、export
curl -sfL https://renlm.github.io/script/sh/KubeConfig.sh | \
  SERVER=https://kubernetes.renlm.cn \
  CLUSTER=pubyun \
  NAMESPACE=renlm \
  CONTEXT=test \
  USER=dev \
  IMPERSONATE_USER=dev-admin \
  bash -s admin - new
```

## Nocalhost
	# 拷贝kubeconfig.yml到本地
	# 安装 VS Code Nocalhost 插件
	https://nocalhost.dev/zh-CN/docs/introduction
	https://kubernetes.io/zh-cn/docs/reference/kubernetes-api
	
```	
# 测试与提权（运维团队）
export DEVOPS_HOME=~/.kube/devops
export DEVOPS_KCFG=$DEVOPS_HOME/devops.kubeconfig
openssl x509 -noout -text -in $DEVOPS_HOME/devops.crt
kubectl --kubeconfig $DEVOPS_KCFG auth can-i create pods -A
kubectl --kubeconfig $DEVOPS_KCFG auth can-i create pods -A --as devops-cluster-admin
```

```	
# 测试与提权（开发团队）
export DEV_HOME=~/.kube/dev
export DEV_KCFG=$DEV_HOME/dev.kubeconfig
openssl x509 -noout -text -in $DEV_HOME/dev.crt
kubectl --kubeconfig $DEV_KCFG auth can-i update pods -n renlm
kubectl --kubeconfig $DEV_KCFG auth can-i update pods -n renlm --as dev-admin
```
