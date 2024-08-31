# MYGRAPH

## 安装 K3S | RKE2
<a href="https://renlm.github.io/doc/K3S.html" target="_blank">https://<span></span>renlm.github.io/doc/K3S.html</a>  

## NFS 配置  
<a href="https://renlm.github.io/doc/NFS.html" target="_blank">https://<span></span>renlm.github.io/doc/NFS.html</a>  

## 创建 Secret
	https://kubernetes.p2hp.com/docs/concepts/configuration/secret.html
	$ kubectl create namespace renlm
	$ kubectl label namespace renlm istio-injection=enabled
	
```
密码
$ export DEFAULT_PASSWORD=PWD@20xxKplstdm^8uttm$

配置文件（values.yaml）
$ cat <<EOF | tee .values.yaml
appVersion: v1
host: mygraph.renlm.cn
env: prod
initDb: true
gateway: istio-system/gateway
redis:
  enabled: true
mysql:
  enabled: true
  nfs:
    enabled: true
    storage: 20Gi
    path: /nfs_share/mysql
    server: 192.168.16.3
rabbitmq:
  enabled: true
  gateway: istio-system/gateway
  host: rabbitmq.renlm.cn
  nfs:
    enabled: true
    storage: 5Gi
    path: /nfs_share/rabbitmq
    server: 192.168.16.3
jenkins:
  enabled: false
  gateway: istio-system/gateway
  host: jenkins.renlm.cn
  nfs:
    enabled: true
    storage: 20Gi
    path: /nfs_share/jenkins
    server: 192.168.16.3
EOF

配置文件（MySQL）
$ cat <<EOF | tee .MySQL.env
{
  "MYSQL_DATABASE": "mygraph",
  "MYSQL_USER": "mygraph",
  "MYSQL_PASSWORD": "$DEFAULT_PASSWORD",
  "MYSQL_ROOT_PASSWORD": "$DEFAULT_PASSWORD"
}
EOF

配置文件（RabbitMQ）
$ cat <<EOF | tee .RabbitMQ.env
{
  "RABBITMQ_DEFAULT_VHOST": "/mygraph",
  "RABBITMQ_DEFAULT_USER": "mygraph",
  "RABBITMQ_DEFAULT_PASS": "$DEFAULT_PASSWORD"
}
EOF

配置文件（Redis）
$ cat <<EOF | tee .Redis.conf
requirepass $DEFAULT_PASSWORD
protected-mode no
port 6379
databases 16
dir /var/lib/redis
EOF
```
	yaml、json工具（手动上传文件，下载较慢）
	https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
	$ apt-get update
	$ apt-get install -y jq
	$ mv yq_linux_amd64 /usr/bin/yq
	$ yq eval -o json .values.yaml |tee .values.json
	
	创建 Secret
	$ kubectl get secret mygraph -n renlm
	$ kubectl delete secret mygraph -n renlm
	$ kubectl -n renlm create secret generic mygraph \
        --from-file=.values.yaml=.values.json \
        --from-file=.MySQL.env=.MySQL.env \
        --from-file=.RabbitMQ.env=.RabbitMQ.env \
        --from-file=.Redis.conf=.Redis.conf
        
    查看 Secret
    $ kubectl -n renlm get secret mygraph --output="jsonpath={.data.\.values\.yaml}" | base64 -d | jq
    $ kubectl -n renlm get secret mygraph --output="jsonpath={.data.\.MySQL\.env}" | base64 -d | jq
    $ kubectl -n renlm get secret mygraph --output="jsonpath={.data.\.RabbitMQ\.env}" | base64 -d | jq
    $ kubectl -n renlm get secret mygraph --output="jsonpath={.data.\.Redis\.conf}" | base64 -d
	  	
## 部署服务
	https://helm.sh/zh/docs/helm/helm_install/
	$ helm upgrade --install mygraph mygraph \
        --repo https://renlm.github.io/helm/repo \
        --namespace renlm --create-namespace \
        --version 1.0.1 \
        -f .values.yaml