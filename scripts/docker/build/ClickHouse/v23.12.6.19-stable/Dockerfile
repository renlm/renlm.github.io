FROM ubuntu:24.04

RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list.d/ubuntu.sources \
  && sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list.d/ubuntu.sources \
  && apt-get update \
  && apt-get -y install wget git vim build-essential cmake ccache python3 ninja-build nasm yasm gawk lsb-release wget software-properties-common gnupg --fix-missing \
  && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
  && cd / && git clone --recursive --depth 1 -b v23.12.6.19-stable --single-branch https://github.com/ClickHouse/ClickHouse.git \
  && mkdir /Clang && wget -O /Clang/llvm.sh https://apt.llvm.org/llvm.sh && chmod +x /Clang/llvm.sh && /Clang/llvm.sh \
  && echo export CC=clang-19 >> ~/.bashrc \
  && echo export CXX=clang++-19 >> ~/.bashrc
  
WORKDIR /ClickHouse
