# 深入探究DNS
> 疫情在家，显得无聊，就将计网的东西重新翻出来看了一下，以作之后和朋友聊天的谈资。


# DNS是什么？
DNS，全名**Domain Name System**，翻译过来就是域名系统，是一个分层的分布式数据库，也是一个使得主机能够查询到IP地址的**应用层**协议。因为有了它，使得我们可以方便的直接使用域名，而非可能随时更换的IP地址；可以说，DNS就是一本因特网的电话簿。

说到域名系统，就不得不说明一下域名是什么？

举个最简单的例子`www.baidu.com`就是一个域名，用来做计算机的定位标志；这个用IP地址也是也一样，话说回来，你可以在终端中输入`ping www.baidu.com`就可以获得一个对应的IP地址，直接使用IP地址放到浏览器里，也一样能访问。我当时获取的就是这样一个IP----`180.101.49.11`，放到浏览器里，一样能访问百度。

# 那为什么要设计DNS呢？
我认为有两个原因：

1. 一个最简单的原因就是，IP地址是四段数字，很不容易让人记住，而且还容易记混。就如同，不用电话簿，你能背下几个电话号？
2. 服务器的IP地址是有可能变动的，万一连接的IP地址无效了，岂不就没法使用服务了？或者哪怕你之前连接的服务器IP从不变动，但是你进行的长途的旅行，从北京跑到了西雅图，你总不会还要连接半个地球那边的服务器吧？即为一个域名映射多个IP地址。


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
    1. 所有的 DNS 服务器，都必须同时支持TCP和UDP；
    2. RFC1123中的”未来“已经来到了；
    3. EDNS 并不可靠。
8. [RFC7858 : Specification for DNS over Transport Layer Security (TLS)](https://tools.ietf.org/html/rfc7858)
    1. 引入TLS来保障隐私。
9. [RFC8484 : DNS Queries over HTTPS (DoH)](https://tools.ietf.org/html/rfc8484)
    1. 引入HTTPS。

# 工作原理和流程
## 域名层级
在上面，我们提到了，DNS是**是一个分层的分布式数据库**。DNS服务器就像一棵树一样，从上到下，依次有着不同的能力。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_01.png?raw=true)
与之对应的有四类DNS服务器。
1. 根DNS服务器
2. 顶级域DNS服务器
3. 权威DNS服务器 
        权威名称服务器是名称服务器查询中的最后一站，将IP拼装完成。
4. 本地DNS服务器
        直接接触到的DNS服务器

与此对应，域名的也是有如同上图的层级系统。DNS解析器需要从根DNS服务器查找到顶级域名服务器的 IP 地址，又从顶级域DNS服务器查找到权威域名服务器的 IP 地址，最终从权威DNS服务器查出了对应服务的 IP 地址。

而且，在获得过 IP 地址之后，DNS服务器会缓存一段时间，以便下次拿的时候更快。

## 解析流程
借用之前看过的一张图来表示一下请求流程（这是迭代查询的过程，递归过于简单易懂）
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/Network_02.jpg?raw=true)

1. 客户端会发出一个DNS请求，问www.163.com的IP是啥啊，并发给本地域名服务器 (本地DNS)；
2. 本地DNS收到来自客户端的请求。现在本机的缓存上查找。如果能找到，它直接就返回IP地址。如果没有，本地DNS会往上询问；
3. 根DNS收到来自本地DNS的请求，发现后缀是 .com，继续往顶级域名服务器询问；
4. 本地DNS转向问顶级域名服务器，顶级域名服务器就是大名鼎鼎的比如 .com、.net、 .org这些一级域名，它负责管理二级域名，比如 163.com，所以它能提供一条更清晰的方向。
5. 顶级域名服务器发出权威DNS服务器的地址；
6. 本地DNS转向问权威DNS服务器询问；
7. 权限DNS服务器查询后将对应的IP地址X.X.X.X告诉本地DNS；
8. 本地DNS再将IP地址返回客户端，客户端和目标建立连接。

## 递归查询&迭代查询
递归查询指的是在DNS查询过程中，一直是以本地名称服务器为中心的，DNS客户端只是发出原始的域名查询请求报文，然后就一直处于等待状态的，直到本地名称服务器发来了最终的查询结果。

这个是默认选择。

而迭代查询的过程就是上节那张图一般。所有的流程都是由本地DNS服务器自己搞。迭代查询的要求有以下两点：
1. 客户端的请求报文中没有申请使用递归查询，即在DNS请求报头部的RD字段没有置1。 
2. 客户端在DNS请求报文中申请使用的是递归查询（也就是RD字段置1了），但在所配置的本地名称服务器上是禁用递归查询（DNS服务器一般默认支持递归查询的），即在应答DNS报文头部的RA字段置0。

根据我的理解，之所以递归比迭代多，是因为递归查询，在本地DNS服务器上只用发出一道请求，其余的都是由更上层的DNS服务器去解决，相比于众多的本地DNS服务器，显然上层的DNS服务器会有更好的查询和传递效率。

## DNS服务器其实不止用到UDP
去年我看了大左的一篇文章[为什么 DNS 使用 UDP 协议](https://draveness.me/whys-the-design-dns-udp-tcp/)，初看标题给我两个感觉：
1. 我靠，DNS服务器使用UDP不是很正常，直接原因不就是因为UDP不用保持连接么？
2. 我去，DNS服务器可不止用到UDP啊，30年前就有TCP了；现在（2019年）[有的DNS服务](https://arstechnica.com/information-technology/2019/11/microsoft-announces-plans-to-support-encrypted-dns-requests-eventually/)连HTTPS都要用上了，灯塔也会范这个错误？

当然，随着我看了完了文章，才知道这个不过是一个标题党罢了。

在上面的文档小节中，我们了解了 TCP、TLS、HTTPS 不断加入 DNS 的过程。作为不断成长的方案，最开始的DNS也存在很多的问题，需要不断地去修正。

在最开始设计的DNS方案中，每次DNS的记录是有着512字节限制，但是随着需求的增多，数据包越来越大




# 推荐视频
[DNS是干什么的？修改hosts的原理又是什么？](https://www.bilibili.com/video/BV1Yx411p7KD?from=search&seid=12510614532257440386)

# 参考资料
[Microsoft says yes to future encrypted DNS requests in Windows](https://arstechnica.com/information-technology/2019/11/microsoft-announces-plans-to-support-encrypted-dns-requests-eventually/)

[为什么 DNS 使用 UDP 协议](https://draveness.me/whys-the-design-dns-udp-tcp/)

[趣谈网络协议](http://gk.link/a/100HE)