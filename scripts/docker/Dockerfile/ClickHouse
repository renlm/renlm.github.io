FROM ubuntu:24.04
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list.d/ubuntu.sources \
  && sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list.d/ubuntu.sources \
  && apt-get update \
  && apt-get -y install wget git vim build-essential cmake ccache python3 ninja-build nasm yasm gawk lsb-release wget software-properties-common gnupg --fix-missing \
  && cd / && git clone --recursive --branch v23.12.6.19-stable https://github.com/ClickHouse/ClickHouse.git \
  && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
  && bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)" \
  && echo export CC=clang-19 >> ~/.bashrc \
  && echo export CXX=clang++-19 >> ~/.bashrc
  