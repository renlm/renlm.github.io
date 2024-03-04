# 客户端配置生成

## 环境配置
	# Rancher v2.6.9
	v1.24.17+k3s1
	cert-manager v1.7.1
	
	# RKE2
	v1.24.17
	
## TLS 可选名称
	https://docs.rancher.cn/
	https://docs.rke2.io/reference/server_config
	# Rancher 文档 > 参考指南 > 集群配置 > Rancher Server 配置 > 集群配置参考
	# Rancher 集群管理 > {找到指定集群} > 编辑配置 > 网络 > TLS 可选名称 > kubernetes.renlm.cn
	# Rancher 集群管理 > {找到指定集群} > 轮换证书 > 轮换单个服务证书 > 选择api-server
	
## 启用ssl透传
	Rancher > 工作负载 > DaemonSets > rke2-ingress-nginx-controller > 启动命令加参数--enable-ssl-passthrough
	# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#ssl-passthrough
	
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

## SSL证书
	登录Rancher Kubectl Shell控制台
	https://cert-manager.io/docs/usage/certificate/#creating-certificate-resources
	
	k3s
	$ kubectl apply -f https://renlm.gitee.io/helm/yaml/tls-traefik.yaml
	
	k8s
	$ kubectl apply -f https://renlm.gitee.io/helm/yaml/tls-nginx.yaml

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
curl -sfL https://renlm.gitee.io/script/sh/KubeConfig.sh | \
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
curl -sfL https://renlm.gitee.io/script/sh/KubeConfig.sh | \
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
