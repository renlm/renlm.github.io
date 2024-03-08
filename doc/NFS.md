# NFS

## 服务端
    安装服务
	$ apt-get update
	$ apt-get -y install nfs-kernel-server
	$ apt-get -y install nfs-common
    
    新建共享磁盘目录
    $ mkdir /nfs_share
    $ chmod o+w /nfs_share

    修改nfs配置文件 
    $ vi /etc/exports

    # 将磁盘目录/nfs_share共享给多台服务器
```
/nfs_share 192.168.0.3(insecure,rw,async,no_root_squash,no_subtree_check)
/nfs_share 192.168.16.3(insecure,rw,async,no_root_squash,no_subtree_check)
```

    参数说明：
        insecure         允许从这台机器过来的非授权访问
        rw               该共享目录的权限是可读写（read-write）
        sync             将数据同步写入内存缓冲区与磁盘中（同步模式）
        no_root_squash   将远程根用户当成本地根用户，即不压制root
        no_subtree_check 不检查父目录的权限

    重载配置并验证（修改后无需重启即可生效）
    $ exportfs -rv

    查看本机挂载磁盘信息
    $ showmount -e localhost
        Export list for localhost:
		/nfs_share 192.168.16.3,192.168.0.3
 
    服务启动、重启、停止、查看状态
    $ /etc/init.d/nfs-kernel-server start
    $ /etc/init.d/nfs-kernel-server restart
    $ /etc/init.d/nfs-kernel-server stop
    $ /etc/init.d/nfs-kernel-server status

## 客户端
    新建挂载目录
    $ mkdir /nfs_mount

    nfs支持
	$ apt-get update
	$ apt-get -y install nfs-common

    自动挂载
    $ apt-get -y install autofs
    $ systemctl enable autofs
    $ systemctl start autofs

    添加挂载点与自动挂载路径的映射
    $ vi /etc/auto.master
```
/nfs_mount          /etc/auto.nfs
```
    $ vi /etc/auto.nfs
```
share    -rw,sync    192.168.16.3:/nfs_share
```

    重启自动挂载
    $ systemctl restart autofs

    查看（注意内网放行服务端Nfs端口，否则客户端无法访问共享目录）
    $ cd /nfs_mount/share
    $ df -h