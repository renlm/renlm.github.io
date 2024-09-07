# MAVEN

## 下载安装
<a href="https://maven.apache.org/download.cgi" target="_blank">https://<span></span>maven.apache.org/download.cgi</a>  

## Sonatype
<a href="https://central.sonatype.org" target="_blank">https://<span></span>central.sonatype.org</a>  
<a href="https://oss.sonatype.org" target="_blank">https://<span></span>oss.sonatype.org</a>  

```
Maven-中央仓库验证方式改变
由之前的明文验证改为密文验证
https://central.sonatype.org/publish/generate-token/
```

## GPG 签名
### 生成主密钥
```shell
$ gpg --full-gen-key
    主密钥设置永不过期
    尺寸选最大4096
    记住密码
```

### 创建子密钥[S]
```shell
$ gpg -k --keyid-format LONG
$ gpg --edit-key 7460D27124ED3A54
gpg> addKey
gpg> save

创建两个签名子秘钥[S]，一个2年有效期，一个无限期

列出公钥：
    $ gpg -k --keyid-format LONG
    /home/renlm/.gnupg/pubring.kbx
	------------------------------
	pub   rsa4096/7460D27124ED3A54 2024-09-07 [SC]
	      152FC7754085127FFCD1A5BF7460D27124ED3A54
	uid                 [ultimate] RenLiMing (Java Code Sign) <renlm@21cn.com>
	sub   rsa4096/3376C7E279E63E1E 2024-09-07 [E]
	sub   rsa3072/FB827680FFAF0190 2024-09-07 [S] [expires: 2026-09-07]
	sub   rsa3072/648B4DF075CB8331 2024-09-07 [S]

列出私钥：
    $ gpg -K --keyid-format SHORT
    /home/renlm/.gnupg/pubring.kbx
	------------------------------
	sec   rsa4096/24ED3A54 2024-09-07 [SC]
	      152FC7754085127FFCD1A5BF7460D27124ED3A54
	uid         [ultimate] RenLiMing (Java Code Sign) <renlm@21cn.com>
	ssb   rsa4096/79E63E1E 2024-09-07 [E]
	ssb   rsa3072/FFAF0190 2024-09-07 [S] [expires: 2026-09-07]
	ssb   rsa3072/75CB8331 2024-09-07 [S]

pub：主密钥-公钥
sub：子秘钥-公钥
sec：主密钥-私钥
ssb：子秘钥-私钥

    最重要的主密钥显示：SC（"sign"&"certify"，代表可以签名和认证其它密钥）
    第一个副密钥显示：E（"encrypt"，加密）
    第二个副密钥显示：S（"sign"，签名）

    特性：
        在key id 之后输入！，将强制使用该key
        当多个密钥同时具有某个功能的时候，优先使用最新未吊销的密钥
        公钥、私钥的keyID是相同的，一起被创建，每个公钥对应一个私钥
        一个主密钥可以绑定多个子密钥，平时加密解密使用的都是子密钥，主密钥只有在某些特定的情况下才使用的，比如新建一个子密钥，撤销废除一个子密钥，签名认证别人的密钥等
        正确的使用姿势是导出主私钥备份，删除本机的主私钥，本机只保留子私钥用于日常操作，哪怕子密钥被人盗取，也不影响主密钥，尽最大程度保护你的主密钥
```

### 上传GPG公钥
```shell
$ gpg --keyserver hkp://keyserver.ubuntu.com --send-keys 7460D27124ED3A54

查询地址：
    https://keyserver.ubuntu.com
        同步可能很慢，如果查不到，过段时间再看
    
    同步较慢，可指定公钥服务器查询：
        $ gpg --keyserver hkp://keyserver.ubuntu.com --search-keys 7460D27124ED3A54
        gpg: data source: http://[2620:2d:4000:1007::70c]:11371
		(1)     RenLiMing (Java Code Sign) <renlm@21cn.com>
		          4096 bit RSA key 7460D27124ED3A54, created: 2024-09-07
		Keys 1-1 of 1 for "7460D27124ED3A54".  Enter number(s), N)ext, or Q)uit > Q
```

### 导出保存
```shell
导出指定密钥的私钥部分（master + subkeys）：
    $ gpg --armor --output MyPlugin.pub.asc --export-secret-keys 7460D27124ED3A54

导出子密钥的私钥部分：
    $ gpg --armor --output MyPlugin.3376C7E279E63E1E.pub.asc --export-secret-subkeys 3376C7E279E63E1E!
    $ gpg --armor --output MyPlugin.FB827680FFAF0190.pub.asc --export-secret-subkeys FB827680FFAF0190!
    $ gpg --armor --output MyPlugin.648B4DF075CB8331.pub.asc --export-secret-subkeys 648B4DF075CB8331!

删除密钥：
    $ gpg --delete-secret-and-public-key 7460D27124ED3A54
```

### 导入子秘钥
```shell
$ gpg --import MyPlugin.FB827680FFAF0190.pub.asc

查看：
    $ gpg -K --keyid-format LONG
    gpg: checking the trustdb
	gpg: no ultimately trusted keys found
	/home/renlm/.gnupg/pubring.kbx
	------------------------------
	sec#  rsa4096/7460D27124ED3A54 2024-09-07 [SC]
	      152FC7754085127FFCD1A5BF7460D27124ED3A54
	uid                 [ unknown] RenLiMing (Java Code Sign) <renlm@21cn.com>
	ssb   rsa3072/FB827680FFAF0190 2024-09-07 [S] [expires: 2026-09-07]

        重要的提示，sec#，这里有一个符号#，标识主私钥不在这个电脑上（它应该已经被放在一个极其、极端、极度安全的地方了）。

        导入的秘钥会显示 [unknown] 状态，使用会报警告：
            gpg: WARNING: This key is not certified with a trusted signature!
        可手动修改证书状态为 [ultimate]
            $ gpg --edit-key 7460D27124ED3A54
            gpg> trust
            gpg> save

            再次查看即可看到状态变更
```

### 导出公钥
```shell
强制指定（加!后缀，否则会导出全部）：
	$ gpg --armor --output MyPlugin.FB827680FFAF0190.pub --export FB827680FFAF0190!
```

### 导入公钥
```shell
直接导入：
    $ gpg --import MyPlugin.FB827680FFAF0190.pub
公钥服务器下载（不完全可信）：
    $ gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys FB827680FFAF0190
```

### 签名验证
```shell
签名：
    $ gpg --output xxx.txt.sig --detach-sign xxx.txt

验证：
    $ gpg --verify xxx.txt.sig xxx.txt
```

### 吊销子密钥
```shell
导入主密钥（master + subkeys）：
    $ gpg --import MyPlugin.pub.asc
    主密钥主要用于生成新的子秘钥，吊销子秘钥

本地吊销：
    $ gpg --edit-key 7460D27124ED3A54
    gpg> key 1

	sec  rsa4096/7460D27124ED3A54
	     created: 2024-09-07  expires: never       usage: SC
	     trust: ultimate      validity: ultimate
	ssb* rsa3072/FB827680FFAF0190
	     created: 2024-09-07  expires: 2026-09-07  usage: S
	ssb  rsa3072/648B4DF075CB8331
	     created: 2024-09-07  expires: never       usage: S
	ssb  rsa4096/3376C7E279E63E1E
	     created: 2024-09-07  expires: never       usage: E
	[ultimate] (1). RenLiMing (Java Code Sign) <renlm@21cn.com>

    gpg> revkey
    gpg> save

再次验证签名：
    $ gpg --verify xxx.txt.sig xxx.txt
    gpg: Signature made Sat Sep  7 23:11:57 2024
	gpg:                using RSA key 90A93C62559AD3446A1C2249FB827680FFAF0190
	gpg: Good signature from "RenLiMing (Java Code Sign) <renlm@21cn.com>" [ultimate]
	gpg: WARNING: This subkey has been revoked by its owner!
	gpg: reason for revocation: Key is no longer used

公钥服务器同步：
    $ gpg --keyserver hkp://keyserver.ubuntu.com --send-keys 7460D27124ED3A54
```