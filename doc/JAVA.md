# JAVA 开发

## OpenJDK
免费开源  
<a href="https://jdk.java.net/" target="_blank">https://<span></span>jdk.java.net/</a>  

## Git
<a href="https://git-scm.com/book/zh" target="_blank">https://<span></span>git-scm.com/book/zh</a>  
<a href="https://git-scm.com/download/win" target="_blank">https://<span></span>git-scm.com/download/win</a>  
<a href="https://tortoisegit.org/download" target="_blank">https://<span></span>tortoisegit.org/download</a>  

```
$ git config --global --list
$ git config --global user.name "renlm"
$ git config --global user.email "renlm@21cn.com"
```

```
解决图标状态不显示
    win+R  
        regedit
    打开注册表后
        HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ShellIconOverlayIdentifiers
        所有Tortoise前面加空格，排到最前边
    打开任务管理器
        Ctrl+Alt+Delete
        重启资源管理器
```

## Eclipse
Java集成开发工具，免费开源  
<a href="https://www.eclipse.org/downloads/" target="_blank">https://<span></span>www.eclipse.org/downloads/</a>  
Lombok插件安装  
<a href="https://projectlombok.org/setup/eclipse" target="_blank">https://<span></span>projectlombok.org/setup/eclipse</a>  

## Visual Studio Code
代码编辑器，免费开源  
<a href="https://code.visualstudio.com/" target="_blank">https://<span></span>code.visualstudio.com/</a>  

```
可选插件
	GitLens
    Git Graph
    Nocalhost
    C/C++ Extension Pack
    rust-analyzer
    Vue - Official
    Chinese (Simplified) (简体中文) Language Pack for Visual Studio Code
```

```
设置中文
【Ctrl+Shift+P】
输入 Configure Display Language
选择 中文(简体)zh-cn
```

```
查询 Git Bash 命令位置，打开配置终端设置
添加自定义终端配置 [ Windows Git Bash ] 并设为默认
$ where bash
{
    "terminal.integrated.profiles.windows": {
        "Windows Git Bash": {
            "path": "E:\\Git\\usr\\bin\\bash.exe"
        }
    },
    "terminal.integrated.defaultProfile.windows": "Windows Git Bash"
}
```

## MobaXterm
远程连接工具，免费开源  
<a href="https://mobaxterm.mobatek.net/" target="_blank">https://<span></span>mobaxterm.mobatek.net/</a>  

## DBeaver
数据库连接工具，免费开源  
<a href="https://dbeaver.io/download/" target="_blank">https://<span></span>dbeaver.io/download/</a>  

## SwitchHosts
一个管理、切换多个 hosts 方案的工具，免费开源  
<a href="https://github.com/oldj/SwitchHosts/releases" target="_blank">https://<span></span>github.com/oldj/SwitchHosts/releases</a>  

## CLCL
剪贴板工具，编码利器  
<a href="https://www.nakka.com/soft/index_eng.html" target="_blank">https://<span></span>www.nakka.com/soft/index_eng.html</a>  

## Snipaste  
截图工具  
<a href="https://zh.snipaste.com" target="_blank">https://<span></span>zh.snipaste.com</a>  

## Node.js
<a href="https://nodejs.org" target="_blank">https://<span></span>nodejs.org</a>  
<a href="https://nodejs.cn" target="_blank">https://<span></span>nodejs.cn</a>  

```
PowerShell 执行策略
$ Get-ExecutionPolicy -List
$ Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

启用yarn 
https://yarnpkg.com/getting-started/install
https://www.yarnpkg.cn/getting-started/install
$ corepack enable
$ yarn config set registry https://registry.npmmirror.com
$ yarn set version stable
$ yarn install
```