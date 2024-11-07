# GO 开发

## 下载并安装
<a href="https://go.dev/dl/" target="_blank">https://<span></span>go.dev/dl/</a>  
<a href="https://dl.google.com/go/go1.23.3.windows-amd64.zip" target="_blank">https://<span></span>dl.google.com/go/go1.23.3.windows-amd64.zip</a>  
	
	GOROOT：Go 语言安装根目录的路径，也就是 GO 语言的安装路径
	GOBIN：GO 程序生成的可执行文件（executable file）的路径
	GOPATH：若干工作区目录的路径，是我们自己定义的工作空间
	$ go version
	$ go env
	$ go env -w GO111MODULE=on
	$ go env -w GOPROXY=https://goproxy.cn,direct
	$ go env -w GOSUMDB=goproxy.cn/sumdb/sum.golang.org
	$ go env -w GOPATH=C:\GO\PATH
	
## VSCode
	安装插件
		GO
		CodeRunner

```
go mod download    下载依赖的module到本地cache（默认为$GOPATH/pkg/mod目录）
go mod edit        编辑go.mod文件
go mod graph       打印模块依赖图
go mod init        初始化当前文件夹, 创建go.mod文件
go mod tidy        增加缺少的module，删除无用的module
go mod vendor      将依赖复制到vendor下
go mod verify      校验依赖
go mod why         解释为什么需要依赖
```