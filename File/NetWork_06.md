# 伯阳的网络笔记（七）：HTTPS
> 因为疫情期间在外当志愿者，晚上回家无聊翻翻网络知识，权当记录了。      
> 初始动笔：2019-03-03       
> 修改时间：2019-03-31       

# HTTPS
简单的说，HTTPS == HTTP + TLS。在 HTTP 层下面， TCP 层上面，加入了一个 TLS 层用于加密。

关于 TLS ，可以查看上一篇文章。

HTTPS 采用混合的加密机制，使用公开密钥加密用于传输对称密钥，之后使用对称密钥加密进行通信。


# 证书
Certification Authority，简称 CA，证书颁发机构，是指我们都信任的证书颁发机构。

我们在使用 HTTPS 之前，需要向 CA 申请一份数字证书，数字证书里有证书持有者、证书持有者的公钥等信息，服务器把证书传输给浏览器，浏览器从证书里取公钥就行了，证书就如身份证一样，可以证明“该公钥对应该网站”。

证书在 TLS 握手过程中可以直接的进行操作。

# 中间人攻击

中间人攻击是指攻击者与通讯的两端分别创建独立的联系，并交换其所收到的数据，使通讯的两端认为他们正在通过一个私密的连接与对方直接对话，但事实上整个会话都被攻击者完全控制。

简单的说，就是存在攻击者在请求和响应传输途中，拦截并篡改内容。

我们知道 HTTPS 在最开始会进行 TLS 握手过程，而中间人攻击一般是发生在会话建立之前。

一般是如下的流程：
1. 中间人拦截客户端的 Client Hello ，获取其中的随机数，然后继续发送 Client Hello 给服务器；
2. 服务器发出 Server Hello、Certificate、Server Key Exchange、Server Hello Done，中间人受到消息，并保存；
3. 中间人发送ClientCertificate、ClientKeyExchange、ChangeCipherSpec、Finished。发送ClientCertificate，携带真实的客户端证书，可以在 Charles 的 SSL Proxying Setting 里的 Client Certificate 里配置；
        发送 ClientKeyExchange ，携带伪造的 Client DH 协商参数；和服务器协商出预主密钥，计算出主密钥1；发送ChangeCipherSpec，通知服务器更改密码规范，发送Finished验证密钥。
4. 中间人收到Server的Finished。
收到Server的Finished以后，发送ServerHello给Client，携带伪造的Server随机数；
发送ServerCertificate，携带伪造的Server证书；
发送ServerKeyExchange，携带伪造的Server DH协商参数；
发送CertificateRequest，请求客户端证书；
发送ServerHelloDone，问候结束。