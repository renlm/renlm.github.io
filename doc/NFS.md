# NFS

## 服务端
    IP: 192.168.16.3
	$ apt-get update
	$ apt-get -y install nfs-kernel-server
	$ apt-get -y install nfs-common
    
    新建共享磁盘目录
    $ mkdir /nfs_share
    $ chmod o+w /nfs_share

```
共享节点授权 
$ vi /etc/exports
/nfs_share 192.168.0.3(insecure,rw,async,no_root_squash,no_subtree_check)
/nfs_share 192.168.0.7(insecure,rw,async,no_root_squash,no_subtree_check)
/nfs_share 192.168.16.6(insecure,rw,async,no_root_squash,no_subtree_check)

参数说明：
	insecure         允许从这台机器过来的非授权访问
	rw               该共享目录的权限是可读写（read-write）
	sync             将数据同步写入内存缓冲区与磁盘中（同步模式）
	no_root_squash   将远程根用户当成本地根用户，即不压制root
	no_subtree_check 不检查父目录的权限
```

    重载配置并验证（修改后无需重启即可生效）
    $ exportfs -rv

    查看本机挂载磁盘信息
    $ showmount -e localhost
        Export list for localhost:
		/nfs_share 192.168.16.6,192.168.0.7,192.168.0.3
 
    启动
    $ /etc/init.d/nfs-kernel-server start
    重启
    $ /etc/init.d/nfs-kernel-server restart
    停止
    $ /etc/init.d/nfs-kernel-server stop
    查看状态
    $ /etc/init.d/nfs-kernel-server status
    
    创建挂载目录
    $ mkdir -p /nfs_share/{mysql,jenkins,rabbitmq}
    挂载子目录必须提前创建，否则pod将创建失败
    $ kubectl describe pod mygraph-mysql-0 -n renlm

## 客户端
    nfs支持
	$ apt-get update
	$ apt-get -y install nfs-common

    自动挂载（集群节点后续可忽略）
    $ apt-get -y install autofs
    $ systemctl enable autofs
    $ systemctl start autofs
    
    新建挂载目录
    $ mkdir /nfs_mount

```
添加挂载点
$ vi /etc/auto.master
/nfs_mount          /etc/auto.nfs
```
    
```
自动挂载路径
$ vi /etc/auto.nfs
share    -rw,sync    192.168.16.3:/nfs_share
```

    重启自动挂载
    $ systemctl restart autofs

    查看（注意内网放行服务端Nfs端口）
    $ cd /nfs_mount/share
    $ df -h