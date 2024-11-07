# GO 开发

## 下载并安装
<a href="https://go.dev/dl/" target="_blank">https://<span></span>go.dev/dl/</a>  
<a href="https://dl.google.com/go/go1.23.3.windows-amd64.zip" target="_blank">https://<span></span>dl.google.com/go/go1.23.3.windows-amd64.zip</a>  
	
	GOROOT：Go 语言安装根目录的路径，也就是 GO 语言的安装路径。
	GOPATH：若干工作区目录的路径，是我们自己定义的工作空间。
	GOBIN：GO 程序生成的可执行文件（executable file）的路径。
	$ go env -w GO111MODULE=on
	$ go env -w GOPROXY=https://goproxy.cn,direct
	$ go version
	$ go env