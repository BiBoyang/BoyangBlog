# 深入探究DNS
> 疫情在家，显得无聊，就将计网的东西重新翻出来看了一下，以作之后和朋友聊天的谈资。

# DNS是什么？
DNS，全名**Domain Name System**，翻译过来就是域名系统，是一个分层的分布式数据库，也是一个使得主机能够查询到IP地址的**应用层**协议。因为有了它，使得我们可以方便的直接使用域名，而非可能随时更换的IP地址；可以说，DNS就是一本因特网的电话簿。

说到域名系统，就不得不说明一下域名是什么？

举个最简单的例子`www.baidu.com`就是一个域名，用来做计算机的定位标志；这个用IP地址也是也一样，话说回来，你可以在终端中输入`ping www.baidu.com`就可以获得一个对应的IP地址，直接使用IP地址放到浏览器里，也一样能访问。我当时获取的就是这样一个IP----`180.101.49.11`，放到浏览器里，一样能访问百度。

# 那为什么要设计DNS呢？
我认为有三个原因：

1. 一个最简单的原因就是，IP地址是四段数字，很不容易让人记住，而且还容易记混。就如同，不用电话簿，你能背下几个电话号？
2. 服务器的IP地址是有可能变动的，万一连接的IP地址无效了，岂不就没法使用服务了？或者哪怕你之前连接的服务器IP从不变动，但是你进行的长途的旅行，从北京跑到了西雅图，你总不会还要连接半个地球那边的服务器吧？
3. 还可以为不同的域名映射同一个IP地址。

简单的说，就是DNS让我们使用者和提供服务者之间提供了一道墙，我们并不需要每时每刻的直接接触到，避免一些不必要的问题。当然，这并非天衣无缝。
# 文档
在[维基百科](https://en.wikipedia.org/wiki/Domain_Name_System)中，记录了所有有关的RFC文件，我只记录一些我认为比较重要或者有意义的文件（实际上我也没法一一去阅读它们）。

1. [RFC882 : DOMAIN NAMES - CONCEPTS and FACILITIES](https://tools.ietf.org/html/rfc882)
2. [RFC883 : DOMAIN NAMES - IMPLEMENTATION and SPECIFICATION](https://tools.ietf.org/html/rfc883)
    1. 在1983年11月，发布了第一版的DNS设计。为什么需要DNS，以及缓存、分布式式数据库的内容都在这里提出。
3. [RFC1034 : DOMAIN NAMES - CONCEPTS AND FACILITIES](https://tools.ietf.org/html/rfc1034)
4. [RFC1035 : DOMAIN NAMES - IMPLEMENTATION AND SPECIFICATION](https://tools.ietf.org/html/rfc1035)
    1. 修改和完善了之前的设计方案，添加了TCP作为UDP的补充。
    2. UDP承载的消息限制为512字节，再长的话，会被截断并且TC位设置为标头。
    3. UDP在区域传送不接受UDP协议，需要找个办法稳定传输。

5. [RFC1123:Requirements for Internet Hosts -- Application and Support](https://tools.ietf.org/html/rfc1123)
    1. 未来的DNS记录类型可能会超过512字节，所以我们需要TCP。

6. [RFC6891 : Extension Mechanisms for DNS (EDNS(0))](https://tools.ietf.org/html/rfc6891)
    1. EDNS 为 DNS 提供了扩展功能，让 DNS 通过 UDP 协议携带最多 4096 字节的数据；
7. [RFC7766 : DNS Transport over TCP - Implementation Requirements](https://tools.ietf.org/html/rfc7766)
    1. 所有的DNS服务器，都必须同时支持TCP和UDP；
    2. RFC1123中的”未来“已经来到了；
    3. EDNS并不可靠。
8. [RFC7858 : Specification for DNS over Transport Layer Security (TLS)](https://tools.ietf.org/html/rfc7858)
    1. 引入TLS来保障隐私。
9. [RFC8484 : DNS Queries over HTTPS (DoH)](https://tools.ietf.org/html/rfc8484)
    1. 引入HTTPS。

# 工作原理和流程
## 域名层级
在上面，我们提到了，DNS是**是一个分层的分布式数据库**。DNS服务器就像一棵树一样，从上到下，依次有着不同的能力。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_01.png?raw=true)

与此对应，域名的也是有如同上图的层级系统。DNS解析器需要从根DNS服务器查找到顶级域名服务器的 IP 地址，又从顶级域DNS服务器查找到权威域名服务器的 IP 地址，最终从权威DNS服务器查出了对应服务的 IP 地址。

## 解析流程



1. 电脑客户端会发出一个DNS请求，问www.163.com的IP是啥啊，并发给本地域名服务器 (本地DNS)。那本地域名服务器 (本地DNS) 是什么呢？如果是通过DHCP配置，本地DNS由你的网络服务商（ISP），如电信、移动等自动分配，它通常就在你网络服务商的某个机房。

2. 本地DNS收到来自客户端的请求。你可以想象这台服务器上缓存了一张域名与之对应IP地址的大表格。如果能找到 www.163.com，它直接就返回IP地址。如果没有，本地DNS会去问它的根域名服务器：“老大，能告诉我www.163.com的IP地址吗？”根域名服务器是最高层次的，全球共有13套。它不直接用于域名解析，但能指明一条道路。

3. 根DNS收到来自本地DNS的请求，发现后缀是 .com，说：“哦，www.163.com啊，这个域名是由.com区域管理，我给你它的顶级域名服务器的地址，你去问问它吧。”

4. 本地DNS转向问顶级域名服务器：“老二，你能告诉我www.163.com的IP地址吗？”顶级域名服务器就是大名鼎鼎的比如 .com、.net、 .org这些一级域名，它负责管理二级域名，比如 163.com，所以它能提供一条更清晰的方向。

5. 顶级域名服务器说：“我给你负责 www.163.com 区域的权威DNS服务器的地址，你去问它应该能问到。”

6. 本地DNS转向问权威DNS服务器：“您好，www.163.com 对应的IP是啥呀？”163.com的权威DNS服务器，它是域名解析结果的原出处。为啥叫权威呢？就是我的域名我做主。

7. 权限DNS服务器查询后将对应的IP地址X.X.X.X告诉本地DNS。

8. 本地DNS再将IP地址返回客户端，客户端和目标建立连接。








# 推荐视频
[DNS是干什么的？修改hosts的原理又是什么？](https://www.bilibili.com/video/BV1Yx411p7KD?from=search&seid=12510614532257440386)
