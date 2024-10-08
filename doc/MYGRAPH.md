# MYGRAPH

## 源码地址 
<a href="https://gitee.com/renlm/MyGraph.git" target="_blank">https://<span></span>gitee.com/renlm/MyGraph.git</a>  
<a href="https://github.com/renlm/MyGraph.git" target="_blank">https://<span></span>github.com/renlm/MyGraph.git</a>  

## NFS 配置  
<a href="https://renlm.github.io/doc/NFS.html" target="_blank">https://<span></span>renlm.github.io/doc/NFS.html</a>  

## 安装 DOCKER  
<a href="https://renlm.github.io/doc/DOCKER.html" target="_blank">https://<span></span>renlm.github.io/doc/DOCKER.html</a>  

## 安装 K3S  
<a href="https://renlm.github.io/doc/K3S.html" target="_blank">https://<span></span>renlm.github.io/doc/K3S.html</a>  

## 安装 RANCHER  
<a href="https://renlm.github.io/doc/RANCHER.html" target="_blank">https://<span></span>renlm.github.io/doc/RANCHER.html</a>  

## KubeConfig  
<a href="https://renlm.github.io/doc/KubeConfig.html" target="_blank">https://<span></span>renlm.github.io/doc/KubeConfig.html</a>  

## 创建 Secret
	https://kubernetes.p2hp.com/docs/concepts/configuration/secret.html
	$ kubectl create namespace renlm
	$ kubectl label namespace renlm istio-injection=enabled
	$ export DEFAULT_PASSWORD=@A1b2c3
	$ export NFS_SERVER=192.168.16.3
	
```
配置文件（values.yaml）
$ cat <<EOF | tee values.yaml
appVersion: v1
gateway: istio-ingress/gateway
host: mygraph.renlm.cn
imagePullSecrets: []
image:
  repository: registry.cn-hangzhou.aliyuncs.com/rlm/mygraph
  pullPolicy: Always
  tag: latest
redis:
  appVersion: 7.4.0
  gateway: istio-ingress/gateway
  host: redis.renlm.cn
  image:
    repository: redis
    pullPolicy: IfNotPresent
    tag: 7.4.0
mysql:
  appVersion: 8.0.31
  gateway: istio-ingress/gateway
  host: mysql.renlm.cn
  mini: true
  image:
    repository: mysql
    pullPolicy: IfNotPresent
    tag: 8.0.31
  nfs:
    enabled: true
    storage: 25Gi
    path: /nfs_share/mysql
    server: ${NFS_SERVER}
rabbitmq:
  appVersion: 3.13.2
  gateway: istio-ingress/gateway
  host: rabbitmq.renlm.cn
  image:
    repository: rabbitmq
    pullPolicy: IfNotPresent
    tag: 3.13.2-management
  nfs:
    enabled: true
    storage: 5Gi
    path: /nfs_share/rabbitmq
    server: ${NFS_SERVER}
jenkins:
  appVersion: 2.452.1
  gateway: istio-ingress/gateway
  host: jenkins.renlm.cn
  image:
    repository: jenkins/jenkins
    pullPolicy: IfNotPresent
    tag: lts-jdk17
  nfs:
    enabled: true
    storage: 20Gi
    path: /nfs_share/jenkins
    server: ${NFS_SERVER}
EOF

配置文件（Redis）
$ cat <<EOF | tee redis.conf
requirepass $DEFAULT_PASSWORD
protected-mode no
port 6379
databases 16
dir /var/lib/redis
EOF
```

	master节点即可（手动上传文件，下载较慢）
	https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
	$ wget https://renlm.github.io/helm/yq_linux_amd64
	$ apt-get update
	$ apt-get install -y jq
	$ mv yq_linux_amd64 /usr/bin/yq
	$ chmod +x /usr/bin/yq
	$ yq eval -o json values.yaml |tee values.json
	
	创建 Secret
	$ kubectl get secret -n renlm
	
	$ kubectl delete secret mygraph -n renlm
	$ kubectl -n renlm create secret generic mygraph \
        --from-file=values.yaml=values.json \
        --from-file=redis.conf=redis.conf
        
    $ kubectl delete secret redis-env -n renlm
	$ kubectl -n renlm create secret generic redis-env \
        --from-literal=REQUIREPASS=$DEFAULT_PASSWORD
    
	$ kubectl delete secret mysql-env -n renlm
	$ kubectl -n renlm create secret generic mysql-env \
        --from-literal=MYSQL_DATABASE=mygraph \
        --from-literal=MYSQL_USER=mygraph \
        --from-literal=MYSQL_PASSWORD=$DEFAULT_PASSWORD \
        --from-literal=MYSQL_ROOT_PASSWORD=$DEFAULT_PASSWORD
        
	$ kubectl delete secret rabbitmq-env -n renlm
	$ kubectl -n renlm create secret generic rabbitmq-env \
        --from-literal=RABBITMQ_DEFAULT_VHOST=/mygraph \
        --from-literal=RABBITMQ_DEFAULT_USER=mygraph \
        --from-literal=RABBITMQ_DEFAULT_PASS=$DEFAULT_PASSWORD
        
    查看 Secret
    $ kubectl -n renlm get secret mygraph --output="jsonpath={.data.values\.yaml}" | base64 -d | jq
    $ kubectl -n renlm get secret mygraph --output="jsonpath={.data.redis\.conf}" | base64 -d
    $ echo $(kubectl -n renlm get secret redis-env --output="jsonpath={.data.REQUIREPASS}" | base64 -d)
    $ echo $(kubectl -n renlm get secret mysql-env --output="jsonpath={.data.MYSQL_PASSWORD}" | base64 -d)
    $ echo $(kubectl -n renlm get secret rabbitmq-env --output="jsonpath={.data.RABBITMQ_DEFAULT_PASS}" | base64 -d)
	  	
## 部署服务
	https://helm.sh/zh/docs/helm/helm_install/
	$ helm upgrade --install mygraph mygraph \
        --repo https://renlm.github.io/helm/repo \
        --namespace renlm --create-namespace \
        --version 1.0.1 \
        -f values.yaml \
        --set env=prod \
        --set initDb=true \
        --set redis.enabled=true \
        --set mysql.enabled=true \
        --set rabbitmq.enabled=true \
        --set jenkins.enabled=true

## MySQL
```
bash-4.4# mysql -uroot -p
# 新建用户
mysql>CREATE USER 'dev'@'%' IDENTIFIED WITH mysql_native_password BY '@A1b2c3';
# 新建数据库
mysql>CREATE DATABASE dev;
# 授权
mysql>GRANT ALL PRIVILEGES ON dev.* to 'dev'@'%';
mysql>GRANT SELECT ON performance_schema.* to 'dev'@'%';
mysql>FLUSH PRIVILEGES;
# 切换数据库
mysql>USE dev;
# 修改密码：
mysql>ALTER USER 'dev'@'%' IDENTIFIED WITH mysql_native_password BY '@A3b2c1';
```

## Jenkins
	Jenkins中安装Docker Pipeline插件
	Jenkins中安装Pipeline: Stage View插件
	Jenkins中安装插件Redeploy Rancher2.x Workload Plugin
	https://plugins.jenkins.io/redeploy-rancher2-workload/
	https://www.jenkins.io/doc/pipeline/steps/redeploy-rancher2-workload/#rancherredeploy-redeploy-rancher2-x-workload
	
	Rancher中查看workload
	Rancher中创建Rancher API 密钥
	集群中新建项目，将服务部署的命名空间移动到项目中
	浏览器打开链接，搜索deployments，https://rancher.renlm.cn/v3/projects
	
	添加Gitee访问的全局凭据：Gitee
	添加私有镜像库的全局凭据：Aliyuncs
	添加Rancher API访问的全局凭据：Rancher，类型选择Rancher2.x API Keys
	Dashboard>系统管理>凭据>系统>全局凭据 (unrestricted)

	Jenkins中代码仓库连接报错，更改配置项
	No ECDSA host key is known for github.com and you have requested strict checking.
	Host key verification failed
	Dashboard>系统管理>全局安全配置>Git Host Key Verification Configuration
	
	Jenkins中全局工具配置添加Maven插件
	构建过程中安装Maven失败或者卡住，进入nfs共享目录下{/var/jenkins_home/}tools/hudson.tasks.Maven_MavenInstallation，删除插件目录后再次构建（例：maven-3.8.6）

	新建任务mygraph
	参数化构建过程（ProjectId：项目ID，AppName：应用名称 [mygraph]，部署环境：Profile [prod]）
	流水线定义，选择SCM，完成后保存
	Build with Parameters
