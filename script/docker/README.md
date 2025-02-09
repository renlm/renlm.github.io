# Docker

## 安装
	$ curl -sfL https://github-io.renlm.cn/script/docker/install.sh | \
        # Docker镜像源
        REGISTRY_MIRRORS=https://docker.1ms.run \
        bash -s \
        # Docker工作目录
        /home/docker