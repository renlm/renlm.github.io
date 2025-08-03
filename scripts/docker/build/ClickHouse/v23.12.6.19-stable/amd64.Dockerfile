FROM registry.cn-hangzhou.aliyuncs.com/jsfpx/clickhouse-env:v23.12.6.19-stable
RUN cmake \
  -Bbuild-amd64 \
  -DHAVE_SSE41=0 \
  -DCMAKE_INSTALL_PREFIX=./release \
  -DHAVE_SSE42=0 \
  -DCMAKE_TOOLCHAIN_FILE=cmake/linux/toolchain-x86_64.cmake \
  -DPARALLEL_COMPILE_JOBS=16 \
  -S . \
  -B build
RUN cmake --install build

#[必须] 基础镜像
FROM --platform=linux/amd64 ubuntu:24.04
#[可选] 工作目录
WORKDIR /var/lib/clickhouse
#[必须] 软件
COPY --from=0 /ClickHouse/release /clickhouse
#[必须] 创建用户非root用户运行
RUN groupadd -r clickhouse --gid=101 \
  && useradd -r -g clickhouse --uid=101 --home-dir=/var/lib/clickhouse --shell=/bin/bash clickhouse
#[可选] 安装依赖和常用工具
RUN apt update \
  && apt install --yes --no-install-recommends ca-certificates locales tzdata vim curl
#[必须] 命令拷贝到/usr/bin同时将默认配置拷贝至/etc/对应的目录下, 与官方镜像配置保持一致
RUN ln -s /clickhouse/bin/clickhouse-server /usr/bin/clickhouse-server \
  && ln -s /clickhouse/bin/clickhouse-client /usr/bin/clickhouse-client \
  && ln -s /clickhouse/bin/clickhouse-local /usr/bin/clickhouse-local \
  && cp -r /clickhouse/etc/clickhouse-server /etc/clickhouse-server \
  && cp -r /clickhouse/etc/clickhouse-client /etc/clickhouse-client
#[必须] 数据卷宿主机挂载
VOLUME /var/lib/clickhouse
VOLUME /var/log/clickhouse-server
#[必须] 暴露端口
EXPOSE 9000 8123 9009
#[必须] 启动命令
ENTRYPOINT ["clickhouse-server", "-C", "/etc/clickhouse-server/config.xml"]
