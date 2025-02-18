# Docker

## 安装
	已适配系统：ubuntu、rhel、centos
	系统镜像源：huaweicloud、tencent、aliyun
	Docker 镜像源：https://docker.renlm.cn
	Docker 工作目录：/home/docker
	$ curl -sfL https://github.renlm.cn/scripts/docker/install.sh | \
        OS_MIRRORS=huaweicloud \
        REGISTRY_MIRRORS=https://docker.renlm.cn \
        bash -s /home/docker
	
	清理缓存
	$ docker system df
	$ docker system prune