# 客户端配置生成

## 环境配置
	# Rancher v2.8.3
	v1.27.13+k3s1
	cert-manager v1.14.5
	
	# RKE2
	v1.28.8+rke2r1
	
## 安装 cert-manager
	登录Rancher Kubectl Shell控制台
	https://cert-manager.io/docs/installation/helm/
	$ helm repo add jetstack https://charts.jetstack.io
	$ helm repo update
	$ kubectl get pods --namespace cert-manager
	$ helm install cert-manager jetstack/cert-manager \
		  --namespace cert-manager \
		  --create-namespace \
		  --version v1.14.5 \
		  --set installCRDs=true
	
## 集群工具
	Monitoring
	使用默认配置直接安装
	https://ranchermanager.docs.rancher.com/zh/how-to-guides/advanced-user-guides/monitoring-alerting-guides/customize-grafana-dashboard
	可选仪表板资源，Grafana 实例的默认 Admin 用户名和密码是 admin/prom-operator
	https://grafana.com/grafana/dashboards/13105-k8s-dashboard-cn-20240513-starsl-cn/
	https://grafana.com/grafana/dashboards/12900
	
	OpenTelemetry Collector
	https://opentelemetry.io/docs/kubernetes/operator/
	手动下载资源文件
	修改manager镜像 ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator 为 otel/opentelemetry-operator
	修改kube-rbac-proxy镜像 gcr.io/kubebuilder/kube-rbac-proxy 为 kubebuilder/kube-rbac-proxy
	直接从本地将修改后YAML文件导入集群
	$ kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	
	Istio
	启用CNI、Jaeger
	自定义覆盖文件（扩展tcp代理端口、OpenTelemetry）
	https://istio.io/latest/docs/reference/config/istio.operator.v1alpha1/
	https://preliminary.istio.io/latest/zh/docs/tasks/observability/distributed-tracing/opentelemetry/
	https://renlm.github.io/helm/yaml/install.istio.yaml
	
```
Istio自定义覆盖文件后，编辑YAML修改Kiali配置
或安装完成后修改并重启Kiali
$ kubectl edit configmap -n istio-system kiali
  kiali:
    auth:
      # 默认token
      # https://kiali.io/docs/configuration/authentication/
      strategy: anonymous
    external_services:
      tracing:
        url: ../../http:tracing:16686/proxy/jaeger/search
        in_cluster_url: http://tracing.istio-system.svc:16686/jaeger
        use_grpc: false
```

```
启用Jaeger Monitor
为工作负载rancher-istio-tracing添加环境变量
- METRICS_STORAGE_TYPE=prometheus
- PROMETHEUS_SERVER_URL=http://rancher-monitoring-prometheus.cattle-monitoring-system.svc:9090
- PROMETHEUS_QUERY_SUPPORT_SPANMETRICS_CONNECTOR=true
- PROMETHEUS_QUERY_NAMESPACE=span_metrics
- PROMETHEUS_QUERY_DURATION_UNIT=s
- PROMETHEUS_QUERY_NORMALIZE_CALLS=true
- PROMETHEUS_QUERY_NORMALIZE_DURATION=true
```
		  
## Ingress-nginx（可选）
	登录Rancher Kubectl Shell控制台
	启用allow-snippet-annotations（默认false）
	https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
	https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
	$ kubectl get cm -A | grep ingress
	$ kubectl edit cm -n kube-system rke2-ingress-nginx-controller
		  
## TLS 可选名称（可选）
	https://docs.rancher.cn/
	https://docs.rke2.io/reference/server_config
	# Rancher 文档 > 参考指南 > 集群配置 > Rancher Server 配置 > 集群配置参考
	# Rancher 集群管理 > {找到指定集群} > 编辑配置 > 网络 > TLS 可选名称 > kubernetes.renlm.cn
	# Rancher 集群管理 > {找到指定集群} > 轮换证书 > 轮换单个服务证书 > 选择api-server
	
## 镜像密文（可选）
	# 同一命名空间下使用
	$ kubectl create namespace renlm
	
	# kubectl -n renlm get secret aliyuncs --output="jsonpath={.data.\.dockerconfigjson}" | base64 -d
	$ kubectl -n renlm create secret docker-registry aliyuncs \
	  	--docker-server=registry.cn-hangzhou.aliyuncs.com \
	  	--docker-username=renlm@21cn.com \
	  	--docker-password=PWD

## 安装 docker（可选）
	https://download.docker.com/linux/static/stable/x86_64/
	https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/installation-requirements/install-docker
	$ curl https://releases.rancher.com/install-docker/23.0.6.sh | sh
	$ apt install docker docker-buildx docker-compose

```
	阿里云，获取加速地址并配置
	https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors
	$ mkdir -p /etc/docker
	$ tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [ "https://***.mirror.aliyuncs.com", "https://hub.gog.email", "https://dockerhub.icu" ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "500m", "max-file": "3" },
  "features": { "buildkit" : true }
}
EOF
```
	
	启动服务
	$ systemctl daemon-reload
	$ systemctl enable docker
	$ systemctl restart docker
	
	清理缓存
	$ docker system df
	$ docker system prune
	
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
