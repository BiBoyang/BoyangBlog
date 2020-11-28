### 伯阳的网络笔记（二）：HTTP 基础


#### 网络分层
我们都知道，互联网是一个极其复杂的体系，包含了大量的应用程序和协议、各种类型的端系统、分组交换机和各种类型的链路级媒体。为了将这些整理，我们将整个网路进行了抽象分层。

关于分层，其实有很多种分法，我们一般接受两种：**TCP / IP 分层**和 **OSI 分层** 。分别如下表示。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_02.png?raw=true)

实际上为了简便（~~以及我本身就是客户端开发~~），大家一般只记住五层就可以了。

上文讲的 DNS 工作在应用层。

# 零. HTTP 前传

作为一个 iOS 开发，这里先讲一个故事。

乔布斯在被苹果赶走没多久后成立了一家电脑公司—— NeXT 计算机公司。NeXT 在 1988 年推出了第一个工作站计算机产品 NeXT Computer，大出风头（但是却没卖出去多少台，因为它实在是太贵了）。但是它的面向对象操作系统 —— NeXTSTEP 却留下了深远的影响，iOS 开发中 NS 开头的 API 就是源于此。

发售没过多久，在欧洲核子研究中心工作的一个名叫 Emilio Pagiola 的科学家忽悠来经费，买了当时研究所的第一台 NeXT 计算机。这在当时可是个时髦的玩意啊！那里的科学家纷纷前来把玩。在围观的程序员里，有个叫做 Tim Berners-Lee 的科学家，他不仅把玩了计算机，还开始研究起了当时还算时髦的 Objective-C，并打算解决文本传输的问题。
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_06.jpg?raw=true)

到了 1990 年，Tim Berners-Lee 成功的搭建了世界上第一个 HTTP 服务器和浏览器，然后给他起了一个伟大的名字 —— **World Wide Web**。

# 一. HTTP历史

讲完上面那个故事，大家实际上也明白 HTTP 被创造的原因了—— **我们需要可靠的传输文本的协议**。

**HTTP** 是 **HyperText Transfer Protocol**的缩写，翻译过来时**超文本传输协议**。

> 实际上更严谨的说法是 超文本转移协议，但是大家都这么说了，就以讹传讹了。

最开始的 HTTP 并不完善，被称之为 HTTP/0.9 。到了 1996 年 5 月，版本更新为 1.0，记载于[RFC1945: Hypertext Transfer Protocol -- HTTP/1.0](https://tools.ietf.org/html/rfc1945)。

然后在 1997 年 1 月，公布了当前应用最广泛的 HTTP/1.1 ，记载于[RFC2616:Hypertext Transfer Protocol -- HTTP/1.1](https://tools.ietf.org/html/rfc2616)。

在 2015 年 5 月，HTTP/2 被公布，记载于[RFC7540](https://tools.ietf.org/html/rfc7540)。

而基于 QUIC 的 HTTP/3 的标准正在慢慢推进中，现在可以在 Chrome 中尝试，可以查看[这篇文章](https://quicwg.org/base-drafts/draft-ietf-quic-http.html)查看关于 HTTP/3 的一些事情。


# 二. HTTP 基础

HTTP 是一个应用层协议，使用 TCP 来作为它的传输协议，而非 UDP。HTTP 会先发出一个和服务器的 TCP 连接，一旦连接建立，该客户端就可以和服务器进行传输。TCP 为 HTTP 提供了可靠数据传输服务，服务器发出的每个 HTTP 响应报文都可以最终**完整**的到达客户端；反之亦然。

HTTP/1 并不存储任何关于客户端的状态信息。假如某个特定的客户短短的几秒内请求了几十次同一个对象，服务器并不会因为刚刚提供了该对象就不再反应，而是每次都重新发送该对象，就像完全不记得之前做过的事一样。所以，我们可以说，HTTP 是**无状态的协议**。但是后来为了保存状态，在[RFC6265](https://tools.ietf.org/html/rfc6265)中定义了 Cookie。

HTTP 有两种连接方法：**非持续连接**和**持续连接**。

非持续连接每次请求完数据之后，TCP 连接就会关闭。这样的缺点显而易见：
1. 每次请求都要重新进行 TCP 三次握手，会浪费很多 RTT（Round-Trip Time，往返时间）；
2. 每次 TCP 连接，都需要在客户端和服务器上分配 TCP 缓冲区，这会带来非常多的不必要的负担。

所以说，我们一般采用**持续连接**的方式来解决这个问题。在 TCP 连接上之后，会经过一段超时时间（可配置的超时间隔）之后，HTTP 服务器再将它关闭。

# 3. HTTP 报文结构

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_07.png?raw=true)

报文结构如图所示。

从客户端发往服务器的是**请求报文（request message）**，从服务器发往客户端的是**响应报文（response message）**。

HTTP 报文包含三个部分：
1. **起始行**       
        报文的第一行就是起始行，在请求报文中用来说明要做什么。
2. **首部字段**        
        起始行之后可能会有零个或者多个首部字段。每个首部字段都包含一个名字和一个值，以便于解析，二者用冒号分割。
3. **主体**        
        包含所有类型的数据。请求主体中包括了要发给服务器的数据，以及服务器要返回给客户端的数据。

通用的首部字段如下，还有更多的，直接搜索就好，~~很少有人会把这些东西都背下来~~。

| 首部 | 描述 | 
| :---: | :---: |
|Cache-Control|控制缓存的行为，用于随报文传送缓存的指示|
|Connection| 允许客户端和服务器指定与请求/响应连接有关的选项| 
|Date| 提供日期和时间标志，说明报文是什么时间创建的 |
|Pragma|报文指令，另一种随报文传送指示的方式，但并不专用于缓存。Pragma 是 HTTP/1.1 之前版本的历史遗留字段，仅作为与 HTTP/1.0 的向后兼容而定义。如果想要所有的服务器保持相同的行为，可以考虑发送 Pragma 指令。例如：Pragma: no-cache Cache-Control: no-cache|
|MIME-Version |给出了发送端使用的 MIME 版本 |
|Trailer| 如果报文采用了分块传输编码（chunked transfer encoding）方式，就可以用这个首部列出位于报文拖挂（trailer）部分的首部集合 |
|Transfer- Encoding |告知接收端为了保证报文的可靠传输，对报文采用了什么编码方式 |
|Update| 给出了发送端可能想要 “升级” 使用的新版本或协议|
|Via |显示了报文经过的中间节点（代理、网关）|
|Warning| 错误通知|

# 4. HTTP 状态码

服务器返回的**响应报文**中第一行为状态行，包含了状态码以及原因短语，用来告知客户端请求的结果。

| 状态码 | 类别 | 原因短语 |
| :---: | :---: | :---: |
| 1XX | Informational（信息性状态码） | 接收的请求正在处理 |
| 2XX | Success（成功状态码） | 请求正常处理完毕 |
| 3XX | Redirection（重定向状态码） | 需要进行附加操作以完成请求 |
| 4XX | Client Error（客户端错误状态码） | 服务器无法处理请求 |
| 5XX | Server Error（服务器错误状态码） | 服务器处理请求出错 |

而伴随每个状态码，HTTP还会发送一条解释性的原因短语。整个的状态码如下图所示。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_08.png?raw=true)
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_09.png?raw=true)
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_10.png?raw=true)

除此之外，你还可以点开[这个网站](https://http.cat/)，来看如何用猫比喻状态码。

![](https://http.cat/200)

# 5. HTTP 方法

简单的说，HTTP 中的方法就是告知服务器，客户端的意图是什么。

这里简述几个我认为有意义的方法。

### GET

最常用的方法，常用于请求服务器发送某个资源。
### POST

向服务器输入数据。
### PUT

与GET读取数据相反，PUT 方法会向服务器写入文档。
### DELETE

请求服务器删除 URL 所指定的资源。
### HEAD

与 GET 类似，但服务器在响应中只返回头部。
### TRACE

客户端发起一个请求的时候，这个请求可能要穿过防火墙、代理、网关或其他一些应用程序。每个中间节点都可能会修改原始的 HTTP 请求。TRACE 方法允许客户端在最终请求发送给服务器的时候，看看它变成了什么样子。

## 幂等性&安全性
在 HTTP/1.1 规范中幂等性的定义是：

> Methods can also have the property of "idempotence" in that (aside from error or expiration issues) the side-effects of N > 0 identical requests is the same as for a single request.

从定义上看，HTTP 方法的幂等性是指**一次和多次请求某一个资源应该具有同样的副作用**。

安全性指的是**不会改变服务器状态，也就是说它只是可读的。**

| HTTP 方法 | 幂等性 | 安全性 |
| :---: | :---: | :---: |
|OPTIONS|	yes	|yes|
|GET	|yes	|yes|
|HEAD	|yes	|yes|
|PUT	|yes	|no|
|DELETE	|yes	|no|
|POST	|no	|no|
|PATCH	|no	|no|

POST 和 PATCH 这两个不是幂等性的。

两次相同的 POST 请求会在服务器端创建两份资源，它们具有不同的URI。

对同一 URI 进行多次 PUT 的副作用和一次 PUT 是相同的。

## GET 和 POST 的区别

与很多回答不同，严格的来讲，GET 和 POST 在数据的安全性上没有区别，如果说 POST 会把请求藏起来就是提高了安全性，那也有点太天真了—— HTTP 本身就是一个**明文协议**！

更进一步的说，POST 和 GET 其实没有本质区别，只是在使用上人为的划分了区别。

GET 的语义是请求获取指定的资源————去**读取**一个资源。GET 方法是安全、幂等、可缓存的， GET 方法的报文主体没有任何语义；短时间反复读取一个资源不会造成副作用（幂等的），而且**不会改变服务器的状态**。

POST 的语义是根据请求负荷（报文主体）对指定的资源做出处理，具体的处理方式视资源类型而不同。大多数情况下，POST 是不可缓存的。POST 反复请求一个资源，服务端会反复创建的；而且**会改变服务器的状态**。


# 6. HTTP 缓存

在有很多客户端访问一个服务器页面的时候，服务器会多次传输同一份文档，每次传送给一个客户端。一些相同的字节会在网络中一遍一遍的传输，这些冗余的数据会很快耗尽昂贵的网络带宽，降低传输速度，加重服务器的负载。

服务器可以将某份多次传送的数据放到缓存中，然后由服务器去做一个缓存**再验证**。一个 HTTP GET 报文的基本缓存处理过程包括7个步骤：
![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/NetWork_13.png?raw=true)

1. 接收    
        缓存从网络中读取抵达的请求报文；
2. 解析    
        缓存对报文进行解析，提取 URL 和各种首部；
3. 查询    
        缓存查看是否有本地副本可用，如果没有，就获取一份副本，并保存在本地；
4. 新鲜度检测    
        缓存查看已缓存的副本是否足够新鲜，如果不是，就问服务器是否有任何更新；
5. 创建响应    
        缓存会用新的首部和已缓存的主题来构建一条响应报文；
6. 发送    
        缓存通过网络将响应发回客户端；
7. 日志    
        缓存可选地创建一个日志文件条目来描述这个事物。

缓存的更多细节，包括缓存的首部字段，可以查看 [HTTP缓存控制小结](https://imweb.io/topic/5795dcb6fb312541492eda8c)。

# 7. cookie
cookie 是 HTTP/1.1 提出的，用于识别用户，实现持久化会话。可以笼统的分为两种：**会话 cookie** 和**持久 cookie**。

会话 cookie 是一种临时 cookie ，用户推出浏览器的时候，会话 cookie 就被删除了。而持久 cookie 会被存储起来，甚至电脑重启还存在。

会话 cookie 和持久 cookie 唯一的区别就是它们的过期时间。

### cookie 如果工作的

当用户初次访问服务器的时候，服务器实际上对用户一无所知。不过服务器可以给客户打上一个独特的 cookie （Set-Cookie）。理论上 cookie 能包含任意信息，不过它们一般只包含一个服务器为了进行跟踪而产生的独特的识别码，它可能不止是一串数字，可能会包含一些信息：

```C++
Cookie: name="Bill";phone="6666666"
```

### 和 Session 的关系

session 从字面上讲，就是会话。而实际上 session 是一个抽象的概念，我们可以通过 cookie 来实现 session（也有别的方法）。

session 是存在服务端的，保存更多的用户数据。session 的运行依赖于 session id ，而一般情况下，我们会把 session id 存储在 cookie 中，也可以放到 URL 中。

某种意义上讲， session 指的是服务器上用来存储的特定客户的更多的数据。



# 8. HTTP/1.1 和 HTTP/1 多出来了什么

1. HTTP/1.1 默认是持久连接
2. HTTP/1.1 支持管线化处理
3. HTTP/1.1 支持虚拟主机
4. HTTP/1.1 新增状态码 100
5. HTTP/1.1 支持分块传输编码

这里讲一下前两个。

## 持久连接

在 HTTP/1.0 中，每次发出一个请求，都会进行一次 TCP 三次握手，但是请求完成之后这个连接就结束了。

为了不造成浪费，启用了**持久连接**，将之前用过的 TCP 连接重用，这样就只有第一次请求会导致两次往返延迟，后续请求只会导致一次往返延迟。

## 管线化

持久连接可以让我们重用已有的连接来完成多次应用请求，但多次请求必须严格满足先进先出（FIFO）的队列顺序：发送请求->等待响应完成->再发送客户端队列中的下一个请求。

管线化可以让我们对上述流程进行一个优化：将 FIFO 队列从客户端（请求队列）迁移到服务器（响应队列）。这样通过尽早分派请求，减少响应阻塞。可以进一步消除额外的网络往返。


# 总结

HTTP 是目前最成功的互联网协议之一，HTTP/1 实际上是一个残缺的，不完整的协议，之后推出的 HTTP/1.1 进行了补全，使 HTTP/1.1 成为最经典，用的最多的 HTTP 协议。

它是基于 TCP 协议的一个报文协议，其报文头是不定长且任意扩展的，这也使得这个协议充满了生命力。

而且 HTTP 涉及到的东西非常多，有一句很经典的话：**”没有人能完整描述HTTP协议“**,因为总是能有一些新的扩展和功能，比如说[“用 HTTP 去控制咖啡壶”](https://tools.ietf.org/html/rfc2324)。




# 引用

[HTTP 基础概述](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/HTTP.md)
    
[HTTP Cats](https://http.cat/)           

[HTTP缓存控制小结](https://imweb.io/topic/5795dcb6fb312541492eda8c)

[“用 HTTP 去控制咖啡壶”](https://tools.ietf.org/html/rfc2324)

《图解 HTTP》

《HTTP 权威指南》

《计算机网络：自顶向下方法》

## 时间线

* 因为疫情期间在外当志愿者，晚上回家无聊翻翻网络知识，权当记录了。      
* 初始动笔：2019-02-03       
* 修改时间：2019-03-25