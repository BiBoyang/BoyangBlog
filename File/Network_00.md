# 深入探究DNS
> 疫情在家，显得无聊，就将计网的东西重新翻出来看了一下，以作之后和朋友聊天的谈资。

# DNS是什么？
DNS，全名**Domain Name System**，翻译过来就是域名系统，是一个分层的分布式数据库，也是一个使得主机能够查询到IP地址的应用层协议。因为有了它，使得我们可以方便的直接使用域名，而非可能随时更换的IP地址；可以说，DNS就是一本因特网的电话簿。

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
在上面，我们提到了，DNS是**是一个分层的分布式数据库**,DNS服务器就像一棵树一样，从上到下，fen





# 推荐视频
[DNS是干什么的？修改hosts的原理又是什么？](https://www.bilibili.com/video/BV1Yx411p7KD?from=search&seid=12510614532257440386)

