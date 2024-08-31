# MYGRAPH

## 安装 K3S | RKE2
<a href="https://renlm.github.io/doc/K3S.html" target="_blank">https://<span></span>renlm.github.io/doc/K3S.html</a>  

## NFS 配置  
<a href="https://renlm.github.io/doc/NFS.html" target="_blank">https://<span></span>renlm.github.io/doc/NFS.html</a>  

## 创建 Secret
	$ kubectl create namespace renlm
	$ kubectl label namespace renlm istio-injection=enabled
	
	服务通用密码  
	$ kubectl -n renlm create secret generic mygraph --from-literal=defaultPassword=PWD
    $ echo $(kubectl -n renlm get secret mygraph --output="jsonpath={.data.defaultPassword}" | base64 -d)
	  	
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