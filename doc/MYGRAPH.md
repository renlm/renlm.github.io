# MYGRAPH

## 安装 K3S | RKE2
<a href="https://renlm.github.io/doc/K3S.html" target="_blank">https://<span></span>renlm.github.io/doc/K3S.html</a>  

## NFS 配置  
<a href="https://renlm.github.io/doc/NFS.html" target="_blank">https://<span></span>renlm.github.io/doc/NFS.html</a>  

## 创建 Secret
	$ kubectl create namespace renlm
	$ kubectl label namespace renlm istio-injection=enabled
	
```
密码
$ export DEFAULT_PASSWORD=PWD@20xxKplstdm^8uttm$

配置文件（values.yaml）
$ cat <<EOF | tee .values.yaml
appVersion: v1.0.1
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
$ cat <<EOF | tee .MySQL
{
  "MYSQL_DATABASE": "mygraph"
  "MYSQL_USER": "mygraph"
  "MYSQL_PASSWORD": "$DEFAULT_PASSWORD"
  "MYSQL_ROOT_PASSWORD": "$DEFAULT_PASSWORD"
}
EOF

配置文件（RabbitMQ）
$ cat <<EOF | tee .RabbitMQ
{
  "RABBITMQ_DEFAULT_VHOST": "/mygraph"
  "RABBITMQ_DEFAULT_USER": "mygraph"
  "RABBITMQ_DEFAULT_PASS": "$DEFAULT_PASSWORD"
}
EOF

配置文件（Redis）
$ cat <<EOF | tee .Redis
requirepass $DEFAULT_PASSWORD
protected-mode no
port 6379
databases 16
dir /var/lib/redis
EOF
```
	Secret
	$ kubectl -n renlm create secret generic mygraph --from-literal=host=mygraph.renlm.cn \
        --from-file=.values.yaml=.values.json \
        --from-file=.values.yaml=.MySQL \
        --from-file=.values.yaml=.RabbitMQ \
        --from-file=.values.yaml=.Redis
    $ echo $(kubectl -n renlm get secret mygraph --output="jsonpath={.data.defaultPassword}" | base64 -d)
    $ echo $(kubectl -n renlm get secret mygraph --output="jsonpath={.data.values\.yaml}" | base64 -d)
	  	
## 部署服务
	$ helm upgrade --install mygraph mygraph \
        --repo https://renlm.github.io/helm/repo \
        --namespace renlm --create-namespace \
        --version 1.0.1 \
        --set host=mygraph.renlm.cn \
        --set env=prod \
        --set initDb=true \
        --set defaultPassword=PWD \
        --set redis.enabled=true \
        --set mysql.enabled=true \
        --set mysql.nfs.server=192.168.16.3 \
        --set rabbitmq.enabled=true \
        --set rabbitmq.host=rabbitmq.renlm.cn \
        --set rabbitmq.nfs.server=192.168.16.3 \
        --set jenkins.enabled=true \
        --set jenkins.host=jenkins.renlm.cn \
        --set jenkins.nfs.server=192.168.16.3