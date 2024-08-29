# RANCHER（Ubuntu）

## 安装 rancher
	添加 Helm Chart 仓库
	https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	$ helm search repo rancher
	
	安装 rancher-stable/rancher v2.8.5
	禁用ingress，使用istio网关进行代理和加密
	https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/installation-references/helm-chart-options
	$ kubectl create namespace cattle-system
	$ kubectl label namespace cattle-system istio-injection=enabled
	$ helm fetch rancher-stable/rancher --version=v2.8.5
	$ helm install rancher ./rancher-2.8.5.tgz \
        --namespace cattle-system \
        --set hostname=rancher.renlm.cn \
        --set tls=external \
        --set replicas=1
	
	查看安装情况，完成后根据输出提示获取随机登录密码（admin）
	$ kubectl -n cattle-system get deploy rancher
	$ kubectl -n cattle-system rollout status deploy/rancher
	
	查看资源占用率
	$ kubectl top nodes
	$ kubectl top pods -A
	
	重置密码（admin）
	$ kubectl get pods -n cattle-system -o wide
	$ kubectl -n cattle-system exec -it [POD_NAME] -- reset-password
	
	卸载
	$ helm ls -A
	$ helm uninstall rancher -n cattle-system

## MTU 设置（可选）
	使用 rancher 创建的集群
	为保障通信，集群节点规格不一致时，需要统一MTU
	以值最小的那个节点为基准
	https://projectcalico.docs.tigera.io/networking/mtu
	https://docs.rke2.io/install/network_options

	查看网卡MTU
	$ ip a | grep eth0
	
	MTU检测
	$ ping -s 1451 -M do {目标IP或域名}
	以MTU=1450为例，选用Calico MTU with VXLAN (IPv4)，集群MTU应设置为：1400（差值50 = 1450 - 1400）
	如果使用WireGuard进行跨云集群节点的网络穿透，1400 - 80(40[IPv6] + 32[WireGuard] + 8[ICMP]) = 1320
	运营商可能对UDP数据包有限制，如果使用wstunnel对WireGuard流量进行TCP包装时，MTU = 1320 - 60(40[IPv6] + 20[TCP]) = 1260
	
```
# 协议消耗
IPv4 – 20 Bytes
IPv6 – 40 Bytes
UDP – 8 Bytes
TCP – 20 Bytes
WireGuard – 32 Bytes
ICMP – 8 Bytes
PPPoE – 8 Bytes
```

```
# 修改方式一：
# 创建集群时，[附加配置] 添加参数
installation:
  calicoNetwork:
    mtu: 1260
```
	
```
# 修改方式二：
# 命令修改
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"mtu":1260}}}'
```

## 应用版本回滚
	回滚应用版本后再进行更新
	helm -n {namespace} history {appName}
	$ helm -n renlm history mygraph
	$ helm -n renlm rollback mygraph {version}
