# KubeConfig

## TLS 可选名称（可选）
	https://docs.rancher.cn/
	https://docs.rke2.io/reference/server_config
	# Rancher 文档 > 参考指南 > 集群配置 > Rancher Server 配置 > 集群配置参考
	# Rancher 集群管理 > {找到指定集群} > 编辑配置 > 网络 > TLS 可选名称 > kubernetes.renlm.cn
	# Rancher 集群管理 > {找到指定集群} > 轮换证书 > 轮换单个服务证书 > 选择api-server
	
## KubeConfig
	登录机器（master）
	https://kubernetes.io/zh-cn/docs/tasks/tls/managing-tls-in-a-cluster/
	https://kubernetes.io/zh-cn/docs/reference/access-authn-authz/certificate-signing-requests/
	https://kubernetes.io/zh-cn/docs/reference/kubernetes-api/authorization-resources/role-binding-v1/
	$ apt-get update
	$ apt-get install -y openssl golang-cfssl jq
	
```
# 运维团队
# TYPE：k3s、rke2
# 集群角色：cluster-admin
# 命令动作：new、export
curl -sfL https://renlm.github.io/script/kubernetes/KubeConfig.sh | \
  SERVER=https://kubernetes.renlm.cn \
  TYPE=k3s \
  CLUSTER=pubyun \
  NAMESPACE=renlm \
  CONTEXT=test \
  USER=devops \
  IMPERSONATE_USER=devops-cluster-admin \
  bash -s cluster-admin - new
```

```
# 开发团队
# TYPE：k3s、rke2
# 集群角色：admin
# 命令动作：new、export
curl -sfL https://renlm.github.io/script/kubernetes/KubeConfig.sh | \
  SERVER=https://kubernetes.renlm.cn \
  TYPE=k3s \
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
# Nocalhost 不支持提权配置，在 ClusterRoleBinding 中搜索 devops-cluster-admin，可手动将 devops 用户加入到 ClusterRole/cluster-admin 中
export DEVOPS_HOME=~/.kube/devops
export DEVOPS_KCFG=$DEVOPS_HOME/devops.kubeconfig
openssl x509 -noout -text -in $DEVOPS_HOME/devops.crt
kubectl --kubeconfig $DEVOPS_KCFG auth can-i create pods -A
kubectl --kubeconfig $DEVOPS_KCFG auth can-i create pods -A --as devops-cluster-admin
```

```	
# 测试与提权（开发团队）
# Nocalhost 不支持提权配置，在 RoleBinding 中搜索 dev-admin，可手动将 dev 用户加入到 ClusterRole/admin 中
export DEV_HOME=~/.kube/dev
export DEV_KCFG=$DEV_HOME/dev.kubeconfig
openssl x509 -noout -text -in $DEV_HOME/dev.crt
kubectl --kubeconfig $DEV_KCFG auth can-i update pods -n renlm
kubectl --kubeconfig $DEV_KCFG auth can-i update pods -n renlm --as dev-admin
```
