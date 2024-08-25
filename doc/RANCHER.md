# RANCHER（Ubuntu）

## 安装 rancher
	添加 Helm Chart 仓库
	$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	$ helm search repo rancher
	
	安装 rancher-stable/rancher v2.8.6
	注意：要保障hostname及其一级域名的DNS解析均指向部署服务器
	$ kubectl create namespace cattle-system
	$ helm fetch rancher-stable/rancher --version=v2.8.6
	$ helm install rancher ./rancher-2.8.6.tgz \
        --namespace cattle-system \
        --set hostname=rancher.renlm.cn \
        --set bootstrapPassword="PWD" \
        --set ingress.tls.source=letsEncrypt \
        --set letsEncrypt.email=renlm@21cn.com \
        --set letsEncrypt.ingress.class=traefik
	
	查看安装情况
	$ kubectl -n cattle-system get deploy rancher
	$ kubectl -n cattle-system rollout status deploy/rancher
	
	重置密码（admin）
	$ docker ps | grep rancher/rancher
	$ docker exec -it {CONTAINER ID} reset-password

## MTU 设置（可选）
	为保障通信，集群节点规格不一致时，需要统一MTU
	以值最小的那个节点为基准
	https://projectcalico.docs.tigera.io/networking/mtu
	https://docs.rke2.io/install/network_options

	查看网卡MTU
	$ ip a | grep eth0
	
	MTU检测
	$ ping -s 1451 -M do {目标IP或域名}
	以MTU=1450为例，选用Calico MTU with VXLAN (IPv4) = 1500 - 1450 = 50
	集群MTU应设置为：1450 - 50 = 1400
	
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
    mtu: 1400
```
	
```
# 修改方式二：
# 命令修改
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"mtu":1400}}}'
```

## 应用版本回滚
	回滚应用版本后再进行更新
	helm -n renlm history {部署应用名称}
	$ helm -n renlm history mygraph
	$ helm -n renlm rollback mygraph {版本号}
