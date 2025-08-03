FROM --platform=linux/amd64 ubuntu:24.04

RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list.d/ubuntu.sources \
  && sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list.d/ubuntu.sources \
  && apt-get update \
  && apt-get -y install wget git vim build-essential cmake ccache python3 ninja-build nasm yasm gawk lsb-release wget software-properties-common gnupg --fix-missing \
  && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
  && cd / && git clone --recursive --depth 1 -b v23.12.6.19-stable --single-branch https://github.com/ClickHouse/ClickHouse.git \
  && mkdir /Clang && wget -O /Clang/llvm.sh https://apt.llvm.org/llvm.sh && chmod +x /Clang/llvm.sh && /Clang/llvm.sh \
  && echo export CC=clang-19 >> ~/.bashrc \
  && echo export CXX=clang++-19 >> ~/.bashrc  \
  && cmake -Bbuild-arm64 -DHAVE_SSE41=0 -DCMAKE_INSTALL_PREFIX=./release -DHAVE_SSE42=0 -DCMAKE_TOOLCHAIN_FILE=cmake/linux/toolchain-aarch64.cmake -DPARALLEL_COMPILE_JOBS=16 -S . -B build \
  && cmake --install build

#[必须] 基础镜像
FROM --platform=linux/arm64 ubuntu:24.04
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
