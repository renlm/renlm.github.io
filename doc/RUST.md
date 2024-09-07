# RUST

## MSYS2
<a href="https://www.msys2.org" target="_blank">https://<span></span>www.msys2.org</a>  

```
下载并安装
    开始菜单
        MSYS2 64bit
            MSYS2 MinGW Clang x64
            MSYS2 MinGW UCRT x64
            MSYS2 MinGW x64
            MSYS2 MinGW x86
            MSYS2 MSYS 
安装工具包
    $ pacman -Syu
    $ pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb mingw-w64-x86_64-cmake mingw-w64-x86_64-make
    $ pacman -S mingw-w64-x86_64-toolchain
    $ pacman -S mingw-w64-x86_64-clang
    $ pacman -S mingw-w64-x86_64-yasm mingw-w64-x86_64-nasm
    $ pacman -S mingw-w64-x86_64-freetype
添加环境变量  
    win+R  
        control system
    环境变量 
        MSYS_DIR=C:\msys64
        MINGW64_DIR=C:\msys64\mingw64
        Path添加: %MSYS_DIR%\usr\bin;%MINGW64_DIR%\bin
查看安装版本
    $ gcc -v
    $ g++ -v
    $ cmake -version
查看CMake生成器
    $ cmake -G
```

## RUST
<a href="https://www.rust-lang.org/zh-CN/learn/get-started" target="_blank">https://<span></span>www.rust-lang.org/zh-CN/learn/get-started</a>  
<a href="https://code.visualstudio.com/docs/languages/rust" target="_blank">https://<span></span>code.visualstudio.com/docs/languages/rust</a>  
<a href="https://crates.io" target="_blank">https://<span></span>crates.io</a>  

```
获取最新版本
$ rustup update
$ rustc --version
$ cargo --version

创建 WebAssembly 项目
https://www.rust-lang.org/zh-CN/what/wasm
https://rustwasm.github.io/docs/book/
$ cargo install wasm-pack
$ cargo install cargo-generate
$ cargo generate --git https://github.com/rustwasm/wasm-pack-template.git --name demo
$ cd demo 
$ wasm-pack build

执行测试用例
$ wasm-pack test --chrome
```